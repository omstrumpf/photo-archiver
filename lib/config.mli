open! Core
open! Async

type t =
  { auth_file : string (* File where google-photos credentials are stored *)
  ; db_file : string (* Sqlite3 database file for storing photo archive mappings *)
  ; archive_dir : string (* Directory where photos are archived *)
  }
[@@deriving sexp, fields]

val load : string -> t Core.Or_error.t Async.Deferred.t
val save : to_file:string -> t -> unit Async.Deferred.t
val arg_type : t Command.Param.t
