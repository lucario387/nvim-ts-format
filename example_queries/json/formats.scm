(pair
  ":" @format.append-space)

("," @format.append-newline)

(array
  "[" @format.indent.begin
  "]" @format.indent.dedent)

(array
  (_) @format.append-newline .)

(object
  "{" @format.indent.begin
  (_)
  "}" @format.indent.dedent)

(object
  (pair) @format.append-newline .)

(string) @format.keep

; Remove trailing ,
(
 (_) @format.append-newline
 .
 (ERROR) @format.remove
  (#contains? @format.remove ","))
