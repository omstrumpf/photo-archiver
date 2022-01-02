open! Core
open! Async

val all_archived_files : archive_dir:string -> String.Set.t Deferred.t

val download_photo :
  archive_dir:string ->
  id:string ->
  name:string ->
  created_at:Time_ns.t ->
  download_url:string ->
  Photo.t Deferred.Or_error.t
