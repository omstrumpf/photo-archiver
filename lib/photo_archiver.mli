open! Core
open! Async

val authorize :
  ?output_file:string ->
  client_id:string ->
  client_secret:string ->
  unit ->
  unit Deferred.Or_error.t

val list : auth_file:string -> ?limit:int -> unit -> unit Deferred.Or_error.t

val sync_db :
  ?dry_run:bool ->
  db_file:string ->
  archive_dir:string ->
  unit ->
  unit Deferred.Or_error.t
