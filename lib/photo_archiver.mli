open! Core
open! Async
module Config = Config

val authorize :
  ?output_file:string ->
  client_id:string ->
  client_secret:string ->
  unit ->
  unit Deferred.Or_error.t

val list : ?limit:int -> Config.t -> unit Deferred.Or_error.t
val sync_db : ?dry_run:bool -> Config.t -> unit Deferred.Or_error.t
