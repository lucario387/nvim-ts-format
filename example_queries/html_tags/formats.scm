(element
  (start_tag) @format.indent.begin
  (_)
  (end_tag
    ">") @format.indent.dedent @format.indent.end)

(element
  [
    (self_closing_tag
      (tag_name) @_foo)
    (start_tag
      (tag_name) @_foo)
  ]
  (#not-any-of? @_foo "br" "i" "em" "b" "u" "wbr")) @format.append-newline

(self_closing_tag
  (tag_name)
  (_) @format.prepend-space)

(start_tag
  (tag_name)
  (_) @format.prepend-space)

(comment) @format.append-newline

(script_element
  (start_tag) @format.append-newline
  (end_tag) @format.prepend-newline @format.append-newline)

(style_element
  (start_tag) @format.append-newline
  (end_tag) @format.append-newline)

(element
  (start_tag
    (tag_name) @_foo)
  (text) @format.ignore
  (end_tag) @format.prepend-newline
  (#eq? @_foo "code")) 
