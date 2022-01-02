open! Core
open! Async

(** Recursively lists all files in [archive_dir] *)
val all_archived_files : archive_dir:string -> String.Set.t Deferred.t

(** Generates a path within the archive for a given filename and creation time *)
val archive_path : name:string -> created_at:Time_ns.t -> string
