; inherits: html_tags,common
(template_element
  (start_tag) @format.indent.begin
  (end_tag
    ">") @format.indent.dedent) @format.append-newline

(interpolation
  "{{" @format.indent.begin
  "}}" @format.indent.dedent) @format.append-newline

((text) @format.remove
  (#lua-match? @format.remove "^%s*$"))

; ((text) @format.ignore
;  (#not-lua-match? @format.ignore "^%s*$"))
