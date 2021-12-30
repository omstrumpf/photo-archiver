open! Core

type t = { id : string; archive_path : string }
[@@deriving sexp_of, fields, equal]
