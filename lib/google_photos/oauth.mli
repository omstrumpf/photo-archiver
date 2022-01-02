open! Core
open! Async

(** Credentials required for API access. App credentials, as well as an oauth
    refresh token for the user. *)
type t =
  { client_id : string
  ; client_secret : string
  ; refresh_token : string
  }
[@@deriving sexp, fields]

(** Ask the user to authorize this app for its required scopes, and obtain
    credentials. *)
val authorize_user : client_id:string -> client_secret:string -> t Deferred.Or_error.t

(** Obtain a short-lived access token for a session. *)
val obtain_access_token : t -> string Deferred.Or_error.t
