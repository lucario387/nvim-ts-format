(statement_block
  "{" @format.indent.begin @format.prepend-space
  "}" @format.indent.end @format.indent.dedent)

(
 (function
   (statement_block)) @format.append-newline
 (#not-has-parent? @format.append-newline parenthesized_expression))

(call_expression
  function: (parenthesized_expression)) @format.append-newline


[
  (expression_statement)
  (lexical_declaration)
  (return_statement)
  (import_statement)
  (export_statement)
] @format.append-newline

(named_imports
  "{" @format.append-space
  "}" @format.prepend-space)

(program
  . (_) .) @format.ignore


(template_string) @format.handle-string

[
  "let"
  "const"
  "var"
  "class"
  "new"
  "delete"
  "in"
  "instanceof"
  "typeof"
  "async"
  "await"
  "return"
  "yield"
  "import"
  "export"
  "default"
  "from"
  "as"
  "of"
  "if"
  "else"
  "switch"
  "case"
  "do"
  "while"
  "try"
  "catch"
  "finally"
  "throw"
  "default"
  "function"
] @format.append-space

[
  ; Operators
  "+"
  "+="
  "-"
  "-="
  "&&"
  "&="
  "/="
  "**="
  "<<="
  "<"
  "<="
  "<<"
  "="
  "=="
  "==="
  "!="
  "!=="
  "=>"
  ">"
  ">="
  ">>"
  "||"
  "%"
  "%="
  "*"
  "**"
  ">>>"
  "&"
  "|"
  "^"
  "??"
  "*="
  ">>="
  ">>>="
  "^="
  "|="
  "&&="
  "||="
  "??="

] @format.prepend-space @format.append-space


(formal_parameters "," @format.append-space)


(program
  .
  (_) @format.no-append @format.no-prepend .)
