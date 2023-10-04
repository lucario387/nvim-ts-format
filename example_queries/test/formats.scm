; 
(program
  (_) @format.append-newline)

(program
  .
  (_)
  (_) @_check.
  (_) @format.prepend-newline
  (#not-has-type? @_check comment))

[
  ":"
  "."
] @format.append-space

(list
  "[" @format.indent.begin
  "]" @format.indent.end @format.indent.dedent)

(list
  (_) @format.append-newline
  (#not-has-type? @format.append-newline capture))

(list
  (capture) @format.prepend-space)

(named_node
  name: (identifier) @format.indent.begin
  .
  (_) @format.append-newline
  [
    (negated_field)
    (field_definition)
    (named_node)
    (anonymous_node)
    (list)
    (grouping)
    (predicate)
  ]? @format.append-newline
  (_)
  .
  ")")

(named_node
  (capture) @format.prepend-space)

(anonymous_node
  (capture) @format.prepend-space)

(predicate
  (parameters
    (_) @format.prepend-space))

; ( (grouping "(" @format.indent.begin) @_group (#not-has-parent? @_group
; grouping))
(grouping
  "(" @format.indent.begin
  .
  (_) @format.append-newline
  .
  (_)? @format.append-newline
  (_)
  .
  ")")

(grouping
  (capture) @format.prepend-space)

(grouping
  .
  "(" @format.remove
  .
  (_)
  .
  ")" @format.remove)

[
  (string)
  (quantifier)
] @format.ignore

(comment) @format.qol

(named_node
  name: (identifier)
  .
  "" @format.append-space
  .
  (capture) @format.eol)

((
  (comment) @_jsdoc_comment
  (#lua-match? @_jsdoc_comment "^/[*][*][^*].*[*]/$")
  )@injection.content
  (#set! injection.language "jsdoc"))

((comment) @injection.content
  (#set! injection.language "comment"))
