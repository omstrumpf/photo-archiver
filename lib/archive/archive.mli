open! Core
open! Async

val all_archived_files : archive_dir:string -> String.Set.t Deferred.t
val archive_path : name:string -> created_at:Time_ns.t -> string
