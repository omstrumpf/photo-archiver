open! Core
open! Async
module Photo = Photo

type t

val with_db : db_file:string -> f:(t -> 'a Deferred.Or_error.t) -> 'a Deferred.Or_error.t
val insert_photo : t -> Photo.t -> unit Or_error.t
val lookup_photo : t -> id:string -> Photo.t option Or_error.t
val lookup_photo_by_archive_path : t -> archive_path:string -> Photo.t option Or_error.t
val all_photos : t -> Photo.t String.Map.t Or_error.t
val remove_photo : t -> id:string -> unit Or_error.t
