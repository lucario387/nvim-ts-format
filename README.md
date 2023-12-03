## nvim-ts-format

Write your own formatter and `formatexpr` for any language, made easy with Tree-sitter!

### Installation

- Using [lazy.nvim]
```lua
  { 
    "lucario387/nvim-ts-format" 
    dependencies = { "nvim-treesitter/nvim-treesitter" },
  }
```


### Usage

- Create some queries for a certain language, using the captures listed below, save it as `queries/{lang}/formats.scm`. For r C, it's `queries/c/formats.scm`, for `*.js` files it will be `queries/javascript/formats.scm`.
  - Set `formatexpr` for certain filetypes that they want to use, for example, enabling for json and C
  - Use `require('nvim-ts-format').format_buf(bufnr)` to fully a buffer
```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "json", "c" },
  callback = function()
    vim.bo.formatexpr = "v:lua.require('nvim-ts-format').formatexpr()"
  end
})
```

### Supported Captures

This section assumes you have grasps the basics of 
- [Treesitter queries]
- [Lua patterns]


<details><summary> <b>Summary for the query knowledge: Click to expand!</b></summary>
A query will be used 
</details>

- For captures, all captures used inside `queries/*/formats.scm` files must be of the listed below.
  - If possible, you should avoid capturing quantifiers due to [Neovim quantifiers capture issues] (i.e. `()`)
  - A capture is considered private if its name started with `_`.  If you want to use other captures for other purposes, such as filtering through predicates, please use private captures

- For predicates, directives, these are some of the more useful for writing queries with this plugin.
  - `(#set! ...)`: This will be used for `@format.ignore` and `@format.indent.begin`
  - `(#eq? @capture "abcdef")`, `(#eq? @capture1 @capture2)`: whether the text content of `@capture` is `abcdef`, or check whether the text content of `@capture1` and `@capture2` are the same
  - `(#lua-match? @capture "")` and `(#vim-match? @capture "")`: whether the text content of `@capture` matches a lua/vim regular expression pattern
  - `(#has-type? @capture a b c)` and `(#not-has-type? @capture a b c)`: If the syntax node's name associated with `@capture` is a, b, c, (or not)
  - For the rest, you can check out the list of supported directives and predicates at 
    - [`:h treesitter-predicates`](https://neovim.io/doc/user/treesitter.html#treesitter-predicates) 
    - [`:h treesitter-directives`](https://neovim.io/doc/user/treesitter.html#treesitter-directives)


Below is the list of accepted captures:

#### `@format.remove`

If a syntax node is captured with this, it will be removed from the end file.

Example: Removing trailing `;` from js statements
```query
(experession_statement ";" @format.remove)
```

#### `@format.ignore`, `@format.keep`

These captures will try to keep the content as is. 

`@format.ignore` will also ignore any other captures and stylings applied to this syntax node, while `@format.keep` will not.

- `@format.ignore`: Ignore everything. Keep the stylings as is
  - Side-effect: newlines may be incorrect, as the syntax node doesn't have newlines at the end of it. To offset this, use `(#set! @format.ignore append-newline)`

Example: Ignoring nodes in between a comment with `start-ignore` and `end-ignore`

```query

(
  (comment) @_start
  .
  (_) @format.ignore
  .
  (comment) @_end
  (#lua-match? @_start "start%-ignore")
  (#lua-match? @_end "end%-ignore")
)
```

- `@format.keep`: Telling the formatter to keep the contents of this syntax node as is. This still applies all other captures onto a syntax node, such as prepending newlines/spaces before the node.

Most used: Keep the content of a string

```query
(string) @format.keep
```

#### `@format.indent.begin`, `@format.indent.end`, `@format.indent`

- `@format.indent.begin`: Has 2 usages
  - Adds an extra indentation level to all nodes after it that's under the same parent. Also inserts a newline
  - With a directive `(#set! format.conditional)`, this will instead be used to conditionally add newlines if it deems there's too many 
  check for maxwidth and clump all to a line or not by doing `(#set! format.conditional)`. By default it always add a new line.
- `@format.indent.end`: Subtracts an extra indentation level to all nodes after it that's under the same parent. Usage is rarely needed, but this is kept for certain languages/scopes configurations.
- `@format.indent`: Used only for calculating indentation level while handling certain sections of the file, unused if formatting the entire file.You can ignore this.

#### `@format.indent.dedent`, `@format.indent.zero`

These captures only take effects if the node is in a line with only whitespaces/tabs

- `@format.indent.dedent`: Remove indent_width spaces, or 1 tab from start of current line if the node is the start of the line. This should be used in combination with `@format.indent.end`, to mark the end of an extra level

Example: Usage in C

```query
; With @format.indent.dedent, we get this code:
; {
;   some_code;
; }
; Without
; {
;     some_code;
;     }
(compound_statement
  "{" @format.indent.begin
  "}" @format.indent.dedent)
```

```c
// From the code 
{ some_code; }
// The query above will lead to
{
  some_code;
}
```

- `@format.indent.zero`: Remove all prefixing whitespace/tabs from current line if this is the 
i.e. `#ifdef` in C

```query
[
  "#define"
  "#ifdef"
  "#ifndef"
  "#endif"
] @format.indent.zero
```

Example: For a C code of
```c
int main(){
  #define FOO BAR
}
```

will become
```c
int main() {
#define FOO BAR
}
```


#### `@format.append-newline`, `@format.append-space`, `@format.cancel-append`

Append newlines/spaces, or ignore it

`@format.append-newline` will take precedence over `@format.append-space`

Example: Adding newlines after each statement in C, and spaces after keywords and 
```query
[
  (primitive_type)
  (type_identifier)
] @format.append-space
(expression_statement) @format.append-newline
```



in combination with all C example aboves, will lead to
```c
int main(){
  Foo a;
}
```

#### `@format.prepend-newline`, `@format.prepend-space`, `@format.cancel-prepend`

Prepend newlines/spaces, or ignore it for certain combinations

`@format.prepend-newline` will take precedence over `@format.prepend-space`


### 


### Credits
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter): It was from here that I wanted to develop my own generic formatter
- [Topiary](https://github.com/tweag/topiary): They were first to try this, but it was very hard to adopt this into Neovim, so I wanted to create one. Also, TOML example queries were inspired from their queries


[Neovim quantifiers capture issues]: https://github.com/neovim/neovim/pull/24738
[Treesitter queries]: https://tree-sitter.github.io/tree-sitter/using-parsers#pattern-matching-with-queries
[Lua patterns]: https://www.lua.org/pil/20.2.html
[lazy.nvim]: https://github.com/folke/lazy.nvim
