open! Core
open! Async

module List_library_contents : sig
  module Photo : sig
    type t =
      { id : string
      ; name : string
      ; created_at : Time_ns.t
      ; download_url : string
      }
    [@@deriving fields, sexp_of]
  end

  val submit
    :  access_token:string
    -> ?limit:int
    -> unit
    -> Photo.t list Deferred.Or_error.t
end
