open! Core
open! Async
open Types

module List_library_contents : sig
  val submit :
    access_token:string -> unit -> Media_item.t list Deferred.Or_error.t
end
