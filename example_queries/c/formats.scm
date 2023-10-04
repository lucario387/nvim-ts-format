; inherits: common
(preproc_include
  path: (_) @format.indent.end @format.append-newline)

(
  (preproc_include) @format.append-newline
  .
  (_) @_type
  (#not-has-type? @_type preproc_include))

(compound_statement
  "{" @format.indent.begin
  (_)
  "}" @format.indent.end @format.append-newline @format.indent.dedent
  (#set! @format.indent.dedent "amount" "1"))

(compound_statement
  "{"
  .
  "}" @format.append-newline)

; (if_statement
(parenthesized_expression
  ")" @format.append-space) @format.prepend-space

; )
(for_statement
  "(" @format.prepend-space
  (declaration
    ";" @format.append-space)
  ";" @format.append-space
  ")" @format.append-space)

(for_statement
  "(" @format.prepend-space
  .
  ";" @format.append-space
  .
  ";" @format.append-space
  .
  ")" @format.append-space)

(parameter_list
  ")" @format.append-space)

[
  "#include"
  ","
  (primitive_type)
  (type_identifier)
] @format.append-space

[
  "+"
  "-"
  "*"
  "/"
  "<<"
  ">>"
  "<"
  ">"
  "="
  "=="
  "!="
  "&&"
  "||"
] @format.prepend-space @format.append-space

[
  (comment)
  (expression_statement)
] @format.append-newline

[
  "#define"
  "#ifdef"
  "#ifndef"
  "#elif"
  "#if"
  "#else"
  "#endif"
] @format.indent.zero @format.append-space

(preproc_def
  name: (identifier) @format.append-space) @format.append-newline

(preproc_function_def
  parameters: (preproc_params) @format.append-space) @format.append-newline

(ERROR) @format.ignore
