(block
  "{" @format.indent.begin @format.prepend-space
  "}" @format.indent.dedent @format.indent.end)

(declaration
  (property_name)
  (_) @format.prepend-space) @format.append-newline

[
  (plain_value)
  (integer_value)
] @format.handle-string

(stylesheet
  (rule_set) @format.append-newline)
(stylesheet
  (declaration) @format.no-append)

(selectors
  "," @format.append-newline)
