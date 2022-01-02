open! Core
open! Async

val download_photo :
  from_url:string -> to_file:string -> unit Deferred.Or_error.t
