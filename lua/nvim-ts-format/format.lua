local ts = vim.treesitter
local get_node_text = vim.treesitter.get_node_text
--- @type TSFormatOpts
local configs = {}
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
      ["format.remove"] = {},
      ["format.ignore"] = {},
      ["format.keep"] = {},
      ["format.indent"] = {},
      ["format.indent.begin"] = {},  -- +1 shiftwidth
      ["format.indent.end"] = {},    -- -1 shiftwidth
      ["format.indent.dedent"] = {}, -- -1 shiftwidth for this line only
      ["format.indent.zero"] = {},   -- zero-d indent
      ["format.prepend-space"] = {},
      ["format.prepend-newline"] = {},
      ["format.cancel-prepend"] = {},
      ["format.append-space"] = {},
      ["format.append-newline"] = {},
      ["format.cancel-append"] = {},
      ["format.handle-string"] = {},
    }

    local query = ts.query.get(lang, "formats")
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
        map["format.indent"][node:parent():id()] = metadata or {}
      end
    end

    return map
  end, function(bufnr, root, lang)
    return tostring(bufnr) .. root:id() .. "_" .. lang
  end
)

---@type fun(bufnr: integer, filetype: string): TSFormatFtOpts
local get_ft_opts = memoize(function(_, ft)
  return configs[ft] and configs[ft] or {
    indent_type = vim.filetype.get_option(ft, "expandtab") and "spaces" or "tabs",
    max_width = vim.filetype.get_option(ft, "textwidth") ~= 0 and
    vim.filetype.get_option(ft, "textwidth") --[[@as integer]] or nil,
    indent_width = vim.filetype.get_option(ft, "expandtab") and
        vim.filetype.get_option(ft, "shiftwidth") --[[@as integer]] or
        vim.filetype.get_option(ft, "tabstop") --[[@as integer]],
  } --[[@as TSFormatFtOpts]]
end, function(bufnr, ft)
  return tostring(bufnr) .. ft
end)

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


---@type fun(parser: LanguageTree, root: TSNode, bufnr: integer): table<string, InjectionTree>
local get_injections = memoize(
  ---@param parser LanguageTree
  ---@return table<string, InjectionTree>
  function(parser, _, _)
    local ignored_injections = {
      comment = true, -- This is useless
      luap = true,
      regex = true,
    }
    ---@type table<string, InjectionTree>
    local injections = {}

    parser:for_each_tree(function(parent_tree, parent_ltree)
      if ignored_injections[parent_ltree:lang()] then
        return
      end
      local parent = parent_tree:root()
      for _, child in pairs(parent_ltree:children()) do
        if ignored_injections[child:lang()] then
          return
        end
        for _, tree in pairs(child:trees()) do
          local r = tree:root()
          local node = assert(parent:named_descendant_for_range(r:range()))
          local id = node:id()
          if not injections[id] or r:byte_length() > injections[id].root:byte_length() then
            injections[id] = {
              lang = child:lang(),
              root = r,
            }
          end
        end
      end
    end)

    return injections
  end,
  ---@param parser LanguageTree
  ---@param root TSNode
  ---@param bufnr integer
  ---@return string
  function(parser, root, bufnr)
    return tostring(bufnr) .. root:id() .. parser:lang()
  end)

--- Iterate over the trees, also iterating over injected trees
--- @param bufnr integer buffer number
--- @param lines string[] The result to print out
--- @param node TSNode starting node for iteration
--- @param root TSNode root node of the tree
--- @param level integer indent level for current line
--- @param lang string language of the current tsnode tree being iterated over
--- @param injections table<string, InjectionTree> Mapping of node ids to root nodes of injected language trees
--- @param fmt_start_row? integer Limit the formatting range to nodes with start row not smaller than fmt_start_row
--- @param fmt_end_row? integer Limit the formatting range to nodes whose end row is not larger than fmt_end_row
local function traverse(bufnr, lines, node, root, level, lang, injections, fmt_start_row, fmt_end_row)
  local q = get_formats(bufnr, root, lang)
  local ft_opts = get_ft_opts(bufnr, vim.bo[bufnr].ft)
  local indent_size = ft_opts.indent_width
  local indent_str = ft_opts.indent_type == "spaces" and string.rep(" ", indent_size) or "\t"
  local max_width = ft_opts.max_width

  -- TODO: Need to handle custom injection cases
  -- Learn how to clip into injected ranges
  -- if q["format.handle-string"][node:id()] then
  --   if injections[node:id()] then
  --     local root = injections[node:id()].root
  --     local r_srow, r_scol, r_sbyte = root:start()
  --     local r_erow, r_ecol, r_ebyte = root:end_()
  --     local srow, scol = node:start()
  --     return
  --   end
  --   if node:named_child_count() == 0 then
  --     local text = get_node_text(node, bufnr):gsub("\r\n", "\n")
  --     local ignored_lines = vim.split(text, "\n+", { trimempty = true })
  --     append_lines(lines, ignored_lines, {})
  --     lines[#lines] = string.rep(indent_str, level)
  --     -- immediately split + handle the string
  --   else
  --     local start_row, start_col = node:start()
  --     local end_row, end_col = node:child(0):start()
  --     if start_col < end_col then
  --       append_lines(lines, vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {}), {})
  --     end
  --     for i = 0, node:child_count() - 1, 1 do
  --       local cur = node:child(i) --[[@as TSNode]]
  --       local next = node:child(i + 1) --[[@as TSNode]]
  --       start_row, start_col = cur:end_()
  --       if i == node:child_count() - 1 then
  --         end_row, end_col = node:end_()
  --       else
  --         end_row, end_col = next:start()
  --       end
  --       local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
  --       if injections[cur:id()] then
  --         local injection = injections[cur:id()]
  --         traverse(bufnr, lines, injection.root, injection.root, level, injection.lang, injections, fmt_start_row,
  --           fmt_end_row)
  --       elseif cur:named() then
  --         traverse(bufnr, lines, cur, root, level, lang, injections, fmt_start_row, fmt_end_row)
  --       else
  --         lines[#lines] = lines[#lines] .. cur:type()
  --       end
  --       append_lines(lines, text, {})
  --     end
  --     return
  --     -- Most likely there needs to have some handling for those named nodes, so try to retrieve the text inbetween the node's range as well
  --   end
  -- end

  ---@type boolean?
  local apply_indent_begin = false
  ---@type boolean?
  local apply_newline = false
  ---@type boolean?
  local has_conditional_indent = false

  for child, _ in node:iter_children() do
    local c_srow = child:start()
    local c_erow = child:end_()
    local id = child:id()
    repeat
      if fmt_start_row and c_erow < fmt_start_row then
        -- This should mean we haven't reach the first line to edit yet, so modify the first line accordingly
        if q["format.indent.begin"][id] then
          has_conditional_indent = q["format.indent.begin"][id]["format.conditional"]
          if has_conditional_indent == nil then
            level = level + 1
            lines[#lines] = string.rep(indent_str, level)
          else
            local _, _, c_sbyte = child:start()
            local _, _, sbyte = node:start()
            if max_width > node:byte_length() + sbyte - c_sbyte + (level * indent_size) then
              has_conditional_indent = false
              level = level - 1
              lines[#lines] = string.rep(indent_str, level)
            end
          end
        end
        if q["format.indent.end"][id] then
          if not has_conditional_indent == false then
            level = level - 1
            has_conditional_indent = false
            lines[#lines] = string.rep(indent_str, level)
          end
        end
        break
      elseif fmt_end_row and fmt_end_row < c_srow then
        -- We go too out of the range to care about. Skip it
        return
      end
      -- If the node is ignored, ignore and write it as is
      -- If node have injections, ignore completely, let the injected tree handle the texts
      -- Some injected nodes are inside a string range, which will be handled by `format.handle-string above`
      -- so it should not reach here

      if q["format.remove"][id] then
        break
      end
      if apply_newline then
        -- Defer adding newline until actually reaching a new node that can be reached.
        -- If not
        apply_newline = false
        lines[#lines + 1] = string.rep(indent_str, level)
      end
      if q["format.ignore"][id] or (child:type() == "ERROR" and child:named_child_count() == 0) then
        -- Just ignore ERROR nodes to be safe
        local text = get_node_text(child, bufnr):gsub("\r\n?", "\n")
        local ignored_lines = vim.split(text, "\n", { trimempty = true })
        append_lines(lines, ignored_lines, { append_newline = q["format.ignore"][id]["append-newline"] })
        break
      elseif injections[id] then
        local injection = injections[id]
        traverse(bufnr, lines, injection.root, injection.root, level, injection.lang, injections, fmt_start_row,
          fmt_end_row)
        break
      end
      if not q["format.cancel-prepend"][id] then
        if q["format.prepend-newline"][id] and (not fmt_start_row or fmt_start_row <= c_srow) then
          lines[#lines + 1] = string.rep(indent_str, level)
        elseif q["format.prepend-space"][id] then
          if has_conditional_indent and apply_indent_begin then
            if not lines[#lines]:match("^%s*$") then
              lines[#lines + 1] = string.rep(indent_str, level)
            end
          else
            lines[#lines] = lines[#lines] .. " "
          end
        end
      end
      -- if q["format.handle-string"][id] then
      --   traverse(bufnr, lines, child, root, level, lang, injections, fmt_start_row, fmt_end_row)
      -- else
      if child:named_child_count() == 0 or q["format.keep"][id] then
        append_lines(lines,
          vim.split(string.gsub(get_node_text(child, bufnr), "\r\n?", "\n"), "\n+", { trimempty = true }), {})
      else
        traverse(bufnr, lines, child, root, level, lang, injections, fmt_start_row, fmt_end_row)
      end
      if q["format.indent.begin"][id] then
        if max_width and q["format.indent.begin"][id]["format.conditional"] then
          has_conditional_indent = true
          local _, _, c_sbyte = child:start()
          local _, _, sbyte = node:start()
          if math.max(0, max_width - #lines[#lines]) < node:byte_length() + sbyte - c_sbyte then
            apply_indent_begin = true
            apply_newline = true
            level = level + 1
            q["format.indent.begin"][id]["format.conditional"] = true
          else
            q["format.indent.begin"][id]["format.conditional"] = false
            apply_indent_begin = false
            apply_newline = false
          end
          break
        else
          if not q["format.indent.begin"][id]["format.conditional"] then
            apply_indent_begin = true
            apply_newline = true
            level = level + 1
          end
          break
        end
      end
      if q["format.indent.dedent"][id] then
        if string.match(lines[#lines], "^%s*" .. get_node_text(child, bufnr)) then
          local amount = tonumber(q["format.indent.dedent"][id]["format.amount"]) or 1
          lines[#lines] = string.sub(lines[#lines], 1 + #string.rep(indent_str, amount))
        end
      elseif q["format.indent.zero"][id] and string.match(lines[#lines], "^%s*" .. get_node_text(child, bufnr)) then
        lines[#lines] = string.match(lines[#lines], "^%s*(.*)")
      end

      if q["format.indent.end"][id] then
        if apply_indent_begin then
          level = math.max(level - 1, 0)
        end
        if has_conditional_indent then
          has_conditional_indent = false
          if string.match(lines[#lines], "^%s*" .. get_node_text(child, bufnr)) then
            lines[#lines] = string.sub(lines[#lines], 1 + #string.rep(indent_str, 1))
          end
        end
        apply_indent_begin = nil
      end
    until true
    repeat
      if not q["format.cancel-append"][id] then
        if q["format.append-newline"][id] and ((not fmt_end_row and not fmt_end_row) or (fmt_start_row <= c_srow and c_erow <= fmt_end_row)) then
          lines[#lines + 1] = string.rep(indent_str, level)
        elseif q["format.append-space"][id] then
          lines[#lines] = lines[#lines] .. " "
        end
      end
      -- Append stuffs
    until true
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

  local start_row = lnum - 1
  local start_col = vim.fn.indent(lnum)
  local end_row = math.max(start_row, vim.fn.prevnonblank(start_row + count - 1))
  local end_col = #(vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or "") - 1

  -- Not optimal, but for this we need the most up-to-date language tree possible
  local root = parser:parse({ start_row, end_row + 1 })[1]:root()
  local injections = get_injections(parser, root, bufnr)

  local start_node = root:descendant_for_range(start_row, start_col, end_row, end_col + 1) --[[@as TSNode]]
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
  local ft_opts = get_ft_opts(bufnr, vim.bo[bufnr].filetype)
  local indent_size = ft_opts.indent_width
  local indent_str = ft_opts.indent_type == "spaces" and string.rep(" ", indent_size) or "\t"
  lines[#lines] = string.rep(indent_str, level)
  traverse(bufnr, lines, start_node, root, level, parser:lang(), injections, start_row, end_row)
  while true do
    if #lines > 0 and string.match(lines[#lines], "^%s*$") then
      table.remove(lines, #lines)
    else
      break
    end
  end
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

  --- @type table<string, InjectionTree>
  local injections = get_injections(parser, root, bufnr)
  local lines = { "" }
  traverse(bufnr, lines, root, root, 0, parser:lang(), injections)
  while true do
    if #lines > 0 and string.match(lines[#lines], "^%s*$") then
      table.remove(lines, #lines)
    else
      break
    end
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

return M
