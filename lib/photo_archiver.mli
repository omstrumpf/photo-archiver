open! Core
open! Async

val authorize :
  ?output_file:string ->
  client_id:string ->
  client_secret:string ->
  unit ->
  unit Deferred.Or_error.t

val list :
  auth_file:string -> ?max_photos:int -> unit -> unit Deferred.Or_error.t

val sync_db :
  db_file:string -> archive_dir:string -> unit -> unit Deferred.Or_error.t
