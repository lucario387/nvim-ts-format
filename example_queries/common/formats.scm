(
  (comment) @_begin
  .
  (_) @format.ignore
  .
  (comment) @_end
  (#lua-match? @_begin "ignore開始")
  (#lua-match? @_end "end%-ignore")
  (#set! @format.ignore append-newline 1))

(
  (comment) @_ignore
  .
  (_) @format.ignore
  (#lua-match? @_ignore "format: ignore"))
