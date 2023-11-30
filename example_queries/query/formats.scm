;

(program
  (_) @format.append-newline)

(program (_) @format.no-append .)

(program
  (_) @_che
  .
  (_) @format.prepend-newline
  (#not-has-type? @_che comment))

[
  ":"
  "."
] @format.append-space

(
  "." @format.prepend-space @format.no-append
  .
  ")")

(list
  "[" @format.indent.begin
  "]" @format.indent.end @format.indent.dedent) @format.indent

(list
  "[" @format.remove
  .
  (_) @format.no-append
  .
  "]" @format.remove)

(list
  (capture) @format.prepend-space)
(list
  (_) @format.append-newline
  (#not-has-type? @format.append-newline capture))

(named_node
  name: (identifier) @format.indent.begin
  [
    (list)
    (grouping)
    (negated_field)
    (field_definition)
    (named_node)
    (anonymous_node)
    (predicate)
    "."
  ] @format.append-newline) @format.indent

(named_node
  name: (identifier) @format.indent.begin
  (_) @format.no-append
  .
  ")")

(named_node
  (capture) @format.prepend-space)

(anonymous_node
  (capture) @format.prepend-space)

(predicate
  (parameters
    (_) @format.prepend-space))
; (
;   (grouping
;   "(" @format.indent.begin) @_group
;   (#not-has-parent? @_group grouping))

(grouping
  "(" @format.ignore
  .
  (_
    (capture)) @format.indent.begin @format.indent
  .
  (predicate) .)

(grouping
  "(" @format.indent.begin
  [
    (anonymous_node)
    (named_node)
    (list)
    (predicate)
    "."
  ] @format.append-newline
  (_) .) @format.indent

(string) @format.keep

(quantifier) @format.ignore
