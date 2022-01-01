open! Core

type t = { id : string; archive_path : string; created_at : Time_ns.t }
[@@deriving sexp_of, fields, equal]
