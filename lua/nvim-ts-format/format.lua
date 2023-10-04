local ts = vim.treesitter
local get_node_text = vim.treesitter.get_node_text
local M = {}


---@class UserOptions
---@field indent_type "space"|"tab"
---@field indent_width integer

---@class InjectionTree
---@field lang string
---@field root TSNode

---@class FormatOpts
---@field indent_type "tab" | "space"
---@field max_width integer


--- @type FormatOpts
local default_options = {
  indent_type = "space",
  max_width = 120,
}

--- Taken from nvim-treesitter
--- Memoize a function using hash_fn to hash the arguments.
--- @generic F: function
--- @param fn F
--- @param hash_fn fun(...): any
--- @return F
local function memoize(fn, hash_fn)
  local cache = setmetatable({}, { __mode = "kv" }) ---@type table<any,any>

  return function(...)
    local key = hash_fn(...)
    if cache[key] == nil then
      local v = fn(...) ---@type any
      cache[key] = v ~= nil and v or vim.NIL
    end

    local v = cache[key]
    return v ~= vim.NIL and v or nil
  end
end


--- Efficiently insert items into the middle of a list.
---
--- Calling table.insert() in a loop will re-index the tail of the table on
--- every iteration, instead this function will re-index  the table exactly
--- once.
---
--- Based on https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating/53038524#53038524
---
---@param t any[]
---@param first integer
---@param last integer
---@param v any
local function list_insert(t, first, last, v)
  local n = #t

  -- Shift table forward
  for i = n - first, 0, -1 do
    t[last + 1 + i] = t[first + i]
  end

  -- Fill in new values
  for i = first, last do
    t[i] = v
  end
end

--- Iterate over captures and use it to process formatexpr
--- @type fun(bufnr: integer, root: TSNode, lang: string): table<string, table<integer, TSMetadata>>
local get_formats = memoize(
---@param bufnr integer
---@param root TSNode
---@param lang string
  function(bufnr, root, lang)
    local map = {
      ["format.indent"] = {},
      ["format.indent.begin"] = {},  -- +1 shiftwidth
      ["format.indent.end"] = {},    -- -1 shiftwidth
      ["format.indent.dedent"] = {}, -- -1 shiftwidth for this line only
      ["format.indent.zero"] = {},   -- zero-d indent
      ["format.prepend-space"] = {},
      ["format.prepend-newline"] = {},
      ["format.append-space"] = {},
      ["format.append-newline"] = {},
      ["format.no-prepend"] = {},
      ["format.no-append"] = {},
      ["format.ignore"] = {},
      ["format.remove"] = {},
      ["format.handle-string"] = {},
      -- ["level"] = {},
    }

    local query = (ts.query.get or ts.get_query)(lang, "formats")
    if not query then
      return map
    end

    for id, node, metadata in query:iter_captures(root, bufnr) do
      if query.captures[id]:sub(1, 1) ~= "_" then
        if not map[query.captures[id]] then
          error("Invalid query in " .. lang .. ": Invalid capture: " .. query.captures[id])
        end
        map[query.captures[id]][node:id()] = metadata or {}
      end
      if query.captures[id] == "format.indent.begin" then
        map["format.indent"][node:parent():id()] = {}
      end
    end
    -- map["level"][root:id()] = 0

    return map
  end, function(bufnr, root, lang)
    return tostring(bufnr) .. root:id() .. "_" .. lang
  end
)

---@class AppendLineOpts
---@field prepend_newline? boolean if true, insert entire text from a newline. Otherwise, start from the last line
---@field append_newline? boolean

---@param lines string[]
---@param lines_to_append string[]
---@param opts AppendLineOpts
local function append_lines(lines, lines_to_append, opts)
  if opts.prepend_newline then
    lines[#lines + 1] = ""
  end
  for i = 1, #lines_to_append, 1 do
    lines[#lines] = lines[#lines] .. lines_to_append[i]
    if opts.append_newline or i ~= #lines_to_append then
      lines[#lines + 1] = ""
    end
  end
end

---@param parser LanguageTree
---@return table<integer, InjectionTree>
local function get_injections(parser)
  local ignored_injections = {
    comment = true, -- This is useless
    luap = true,
    regex = true,
  }
  ---@type table<integer, InjectionTree>
  local injections = {}

  parser:for_each_tree(function(root_tree, root_ltree)
    if ignored_injections[root_ltree:lang()] then return end
    local root = root_tree:root()
    for _, child in pairs(root_ltree:children()) do
      if not ignored_injections[child:lang()] then
        for _, tree in pairs(child:trees()) do

          local r = tree:root()
          local node = assert(root:named_descendant_for_range(r:range()))
          if not injections[node:id()] or r:byte_length() > injections[node:id()].root:byte_length() then
            injections[node:id()] = {
              lang = child:lang(),
              root = r,
            }
          end
          break
        end
      end
    end
  end)
  return injections
end

--- Iterate over the trees, also iterating over injected trees
--- @param bufnr integer buffer number
--- @param lines string[] The result to print out
--- @param node TSNode starting node for iteration
--- @param root TSNode root node of the tree
--- @param level integer indent level for current line
--- @param lang string language of the current tsnode tree being iterated over
--- @param injections table<integer, InjectionTree> Mapping of node ids to root nodes of injected language trees
--- @param fmt_start_row? integer
--- @param fmt_end_row? integer
local function traverse(bufnr, lines, node, root, level, lang, injections, fmt_start_row, fmt_end_row)
  local q = get_formats(bufnr, root, lang)
  local indent_size = vim.fn.shiftwidth()
  local indent_str = vim.bo[bufnr].expandtab and string.rep(" ", indent_size) or "\t"
  -- local sw = vim.filetype.get_option(, "shiftwidth")
  -- local indent_level = sw ~= 0 and sw or vim.filetype.get_option(vim.)

  -- TODO: Need to handle custom injection cases
  -- Learn how to clip into injected ranges
  if q["format.handle-string"][node:id()] then
    if node:named_child_count() == 0 then
      local text = get_node_text(node, bufnr):gsub("\r\n", "\n")
      local ignored_lines = vim.split(text, "\n+", { trimempty = true })
      append_lines(lines, ignored_lines, {})
      lines[#lines] = string.rep(indent_str, level)
      -- immediately split + handle the string
    else
      local start_row, start_col = node:start()
      local end_row, end_col = node:child(0):start()
      if start_col < end_col then
        append_lines(lines, vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {}), {})
      end
      for i = 0, node:child_count() - 1, 1 do
        local cur = node:child(i) --[[@as TSNode]]
        local next = node:child(i + 1) --[[@as TSNode]]
        start_row, start_col = cur:end_()
        if i == node:child_count() - 1 then
          end_row, end_col = node:end_()
        else
          end_row, end_col = next:start()
        end
        local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
        if injections[cur:id()] then
          local injection = injections[cur:id()]
          traverse(bufnr, lines, injection.root, injection.root, level, injection.lang, injections, fmt_start_row,
            fmt_end_row)
        elseif cur:named() then
          traverse(bufnr, lines, cur, root, level, lang, injections, fmt_start_row, fmt_end_row)
        else
          lines[#lines] = lines[#lines] .. cur:type()
        end
        append_lines(lines, text, {})
      end
      return
      -- Most likely there needs to have some handling for those named nodes, so try to retrieve the text inbetween the node's range as well
    end
  end

  for child, _ in node:iter_children() do
    local c_srow = child:start()
    local c_erow = child:end_()
    if fmt_start_row and c_erow < fmt_start_row then
      -- This should mean we haven't reach the first line to edit yet, so modify the first line accordingly
      if q["format.indent.begin"][child:id()] then
        level = level + 1
        lines[#lines] = string.rep(indent_str, level)
      end
      if q["format.indent.end"][child:id()] then
        level = level - 1
        lines[#lines] = string.rep(indent_str, level)
      end
      goto continue
    elseif fmt_end_row and fmt_end_row < c_srow then
      -- We go too out of the range to care about. Skip it
      return
    end
    if fmt_start_row and fmt_end_row and (c_erow < fmt_start_row or fmt_end_row < c_srow) then
      goto continue
    end
    -- If the node is ignored, ignore and write it as is
    -- If node have injections, ignore completely, let the injected tree handle the texts
    if q["format.remove"][child:id()] then
      goto continue
    end
    if injections[child:id()] and not q["format.ignore"][child:id()] then
      local injection = injections[child:id()]
      traverse(bufnr, lines, injection.root, injection.root, level, injection.lang, injections, fmt_start_row,
        fmt_end_row)
      goto continue
    end
    -- if q["format.replace"][child:id()] then
    --   lines[#lines] = lines[#lines] .. q["format.replace"][child:id()]
    -- end
    if not q["format.no-prepend"][child:id()] then
      if q["format.prepend-newline"][child:id()] then
        lines[#lines + 1] = string.rep(indent_str, level)
      elseif q["format.prepend-space"][child:id()] then
        lines[#lines] = lines[#lines] .. " "
      end
    end
    if q["format.ignore"][child:id()] then
      local text = get_node_text(child, bufnr):gsub("\r\n", "\n")
      local ignored_lines = vim.split(text, "\n+", { trimempty = true })
      append_lines(lines, ignored_lines, { append_newline = q["format.ignore"][child:id()]["append-newline"] })
      goto continue
    elseif child:named_child_count() == 0 then
      append_lines(lines,
        vim.split(string.gsub(get_node_text(child, bufnr), "\r\n", "\n"), "\n+", { trimempty = true }), {})
    else
      traverse(bufnr, lines, child, root, level, lang, injections, fmt_start_row, fmt_end_row)
    end
    if q["format.indent.begin"][child:id()] then
      level = level + 1
      lines[#lines + 1] = string.rep(indent_str, level)
      goto continue
    end
    if q["format.indent.dedent"][child:id()] then
      if string.match(lines[#lines], "^%s*" .. get_node_text(child, bufnr)) then
        local amount = tonumber(q["format.indent.dedent"][child:id()]["amount"]) or 1
        lines[#lines] = string.sub(lines[#lines], 1 + #string.rep(indent_str, amount))
      end
    end

    if q["format.indent.end"][child:id()] then
      level = math.max(level - 1, 0)
      -- lines[#lines + 1] = string.rep(indent_str, level)
    end
    if not q["format.no-append"][child:id()] then
      if q["format.append-newline"][child:id()] then
        lines[#lines + 1] = string.rep(indent_str, level)
      elseif q["format.append-space"][child:id()] then
        lines[#lines] = lines[#lines] .. " "
      end
    end
    -- Append stuffs

    ::continue::
  end
end


---@param lnum integer
---@param count integer
M.format = function(lnum, count)
  local bufnr = vim.api.nvim_get_current_buf()
  ---@type LanguageTree|nil
  local parser = vim.F.npcall(ts.get_parser, bufnr)
  if not parser then
    return 1
  end

  -- local ft = vim.bo[bufnr].filetype
  -- local root_lang = ts.language.get_lang(ft) or ft

  local start_row = lnum - 1
  local start_col = vim.fn.indent(lnum)
  local end_row = vim.fn.prevnonblank(start_row + count - 1)
  local end_col = #(vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or "") - 1

  -- Not optimal, but for this we need the most up-to-date language tree possible
  local root = parser:parse({ start_row, end_row })[1]:root()
  local injections = get_injections(parser)

  local start_node = root:descendant_for_range(start_row, start_col, end_row, end_col) --[[@as TSNode]]
  local whole_file = lnum == 1 and (vim.fn.line("$") == lnum + count - 1)
  local lines = { "" }


  if whole_file then
    traverse(bufnr, lines, root, root, 0, parser:lang(), injections)
    vim.api.nvim_buf_set_lines(bufnr, start_row, start_row + count, false, lines)
    return 0
  end

  if start_node:parent() then
    start_node = start_node:parent() --[[@as TSNode]]
  end

  -- get level to start the children formatting
  local q = get_formats(bufnr, root, parser:lang())
  ---@type TSNode
  local tmp_node = start_node
  local level = 0
  while true do
    if not tmp_node:parent() then
      break
    end
    tmp_node = tmp_node:parent()
    if q["format.indent"][tmp_node:id()] then
      level = level + 1
    end
  end
  local indent_size = vim.fn.shiftwidth()
  local indent_str = vim.bo[bufnr].expandtab and string.rep(" ", indent_size) or "\t"
  lines[#lines] = string.rep(indent_str, level)
  traverse(bufnr, lines, start_node, root, level, parser:lang(), injections, start_row, end_row)
  vim.api.nvim_buf_set_lines(bufnr, start_row, start_row + count, false, lines)
  return 0
end

--- @param bufnr? integer
M.format_buf = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  --- @type LanguageTree|nil
  local parser = vim.F.npcall(ts.get_parser, bufnr)
  if not parser then
    vim.notify("No parser available for buffer " .. bufnr, vim.log.levels.INFO, { title = "Notification" })
    return 1
  end
  local root = parser:parse(true)[1]:root()

  --- @type table<integer, InjectionTree>
  local injections = get_injections(parser)
  local lines = { "" }
  traverse(bufnr, lines, root, root, 0, parser:lang(), injections)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

return M
