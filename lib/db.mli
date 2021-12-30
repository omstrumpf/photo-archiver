open! Core
open! Async

module Photo : sig
  type t = { id : string; archive_path : string }
  [@@deriving sexp_of, fields, equal]
end

type t

val with_db :
  db_file:string -> f:(t -> 'a Deferred.Or_error.t) -> 'a Deferred.Or_error.t

val insert_photo : t -> Photo.t -> unit Or_error.t
val lookup_photo : t -> id:string -> Photo.t option Or_error.t
val all_photos : t -> Photo.t String.Map.t Or_error.t
