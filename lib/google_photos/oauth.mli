open! Core

open! Async
(** Credentials required for operation. App credentials, as well as an oauth
    refresh token for the user. *)

type t = { client_id : string; client_secret : string; refresh_token : string }
[@@deriving sexp, fields]

val authorize_user :
  client_id:string -> client_secret:string -> t Deferred.Or_error.t

val obtain_access_token : t -> string Deferred.Or_error.t
