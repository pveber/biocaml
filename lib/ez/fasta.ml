open Core.Std
open Future_unix.Std
open Future

include Biocaml_unix.Std.Fasta

let sequence_to_int_list s =
  ok_exn (sequence_to_int_list s)

let read0
    ?start
    ?allow_sharp_comments
    ?allow_semicolon_comments
    ?allow_empty_lines
    ?max_line_length
    ?alphabet
    r
  =
  read0
    ?start
    ?allow_sharp_comments
    ?allow_semicolon_comments
    ?allow_empty_lines
    ?max_line_length
    ?alphabet
    r
  |> Pipe.map ~f:ok_exn

let read ?start ?fmt r =
  let header,strm = ok_exn (read ?start ?fmt r) in
  header, Pipe.map strm ~f:ok_exn

let with_file ?fmt file ~f =
  with_file ?fmt file ~f:(fun header strm ->
      Ok (f header (Pipe.map strm ~f:ok_exn))
    )
  |> ok_exn
