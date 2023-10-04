(pair
  ":" @format.append-space)

(array
  "[" @format.indent.begin
  .
  [
    (object
      .
      (_) .)
    (
      (_)
      .
      (_))
  ]
  "]" @format.append-newline @format.indent.dedent)

(array
  ","
  .
  (_) @format.append-newline
  .
  (ERROR)*
  .
  "]")

(array
  (_)
  . "," @format.remove .)

(object
  "{" @format.indent.begin
  (_)
  "}" @format.indent.dedent @format.append-newline)

(object
  (pair)
  .
  "," @format.append-newline)

(object
  ","
  .
  (pair) @format.append-newline . (ERROR)? .)

(string) @format.ignore

; Remove trailing ,
((ERROR) @format.remove
  (#eq? @format.remove ","))
