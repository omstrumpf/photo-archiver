open! Core
open! Async
module Config = Config

(** Obtain google-photos credentials *)
val authorize
  :  ?output_file:string
  -> client_id:string
  -> client_secret:string
  -> unit
  -> unit Deferred.Or_error.t

(** List all photos from google-photos *)
val list : ?limit:int -> Config.t -> unit Deferred.Or_error.t

(** Query for photos, compare against db, and archive missing ones *)
val archive : ?dry_run:bool -> ?limit:int -> Config.t -> unit Deferred.Or_error.t

(** Make sure the database is in sync with the archive *)
val sync_db : ?dry_run:bool -> Config.t -> unit Deferred.Or_error.t
