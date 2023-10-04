(
  ":" @format.indent.begin
  .
  (block) @format.indent.end)

(assignment
  ":" @format.append-space
  type: (type))

[
  "def"
  "class"
  ","
] @format.append-space

[
  "+"
  "-"
  "*"
  "/"
  "**"
  "="
  "=="
] @format.prepend-space @format.append-space

[
  (function_definition)
  (escape_sequence)
  (expression_statement)
] @format.append-newline
