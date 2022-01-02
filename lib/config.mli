open! Core
open! Async

type t =
  { auth_file : string
  ; db_file : string
  ; archive_dir : string
  }
[@@deriving sexp, fields]

val load : string -> t Core.Or_error.t Async.Deferred.t
val save : to_file:string -> t -> unit Async.Deferred.t
val arg_type : t Command.Param.t
