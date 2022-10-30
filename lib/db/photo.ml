open! Core

type t =
  { id : string
  ; name : string
  ; archive_path : string
  ; created_at : Time_ns_unix.t
  }
[@@deriving sexp_of, fields, equal]
