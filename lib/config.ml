open! Core
open! Async

type t = { auth_file : string; db_file : string; archive_dir : string }
[@@deriving sexp, fields]

let load filename = Reader.load_sexp filename t_of_sexp
let save ~to_file t = Writer.save_sexp to_file (sexp_of_t t)

let arg_type =
  let%map_open.Command auth_file =
    flag "-auth-file"
      (required Filename.arg_type)
      ~doc:"Path to file containing auth tokens"
  and db_file =
    flag "-database-file"
      (required Filename.arg_type)
      ~doc:"Path to sqlite3 database file"
  and archive_dir =
    flag "-archive-directory"
      (required Filename.arg_type)
      ~doc:"Path to photo archive directory"
  in
  { auth_file; db_file; archive_dir }
