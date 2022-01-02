open! Core
open! Async
open Cohttp
open Cohttp_async

type t =
  { client_id : string
  ; client_secret : string
  ; refresh_token : string
  }
[@@deriving sexp, fields]

let scope = [ "https://www.googleapis.com/auth/photoslibrary.readonly" ]
let redirect_uri = "urn:ietf:wg:oauth:2.0:oob"

let authorization_uri ~client_id =
  Uri.make
    ~scheme:"https"
    ~host:"accounts.google.com"
    ~path:"/o/oauth2/auth"
    ~query:
      [ "client_id", [ client_id ]
      ; "redirect_uri", [ redirect_uri ]
      ; "scope", scope
      ; "response_type", [ "code" ]
      ; "access_type", [ "offline" ]
      ; "approval_prompt", [ "force" ]
      ]
    ()
;;

module Authorize_response = struct
  type t = { refresh_token : string }
  [@@deriving yojson, fields] [@@yojson.allow_extra_fields]
end

let authorize_user ~client_id ~client_secret =
  let authorization_uri = authorization_uri ~client_id in
  let%bind.Deferred.Or_error authorization_code =
    print_endline
      [%string
        "Please go to the following link in your browser:\n%{authorization_uri#Uri}"];
    print_string "Then, enter the code you get here: ";
    let%bind () = Writer.flushed (force Writer.stdout) in
    match%map Reader.read_line (force Reader.stdin) with
    | `Ok s -> Ok s
    | `Eof -> Or_error.error_s [%message "Failed to read user input"]
  in
  let%bind response, body =
    let uri = Uri.of_string "https://oauth2.googleapis.com/token" in
    let body =
      Body.of_form
        [ "client_id", [ client_id ]
        ; "client_secret", [ client_secret ]
        ; "code", [ authorization_code ]
        ; "grant_type", [ "authorization_code" ]
        ; "redirect_uri", [ redirect_uri ]
        ]
    in
    let headers =
      Header.of_list [ "content-type", "application/x-www-form-urlencoded" ]
    in
    Client.post ~headers ~body uri
  in
  let%bind body_s = Body.to_string body in
  match Cohttp.Response.status response |> Code.code_of_status |> Code.is_success with
  | false ->
    Deferred.Or_error.error_s
      [%message
        "Failed to submit authorization request"
          ~code:(Cohttp.Response.status response |> Code.code_of_status : int)
          ~body:(body_s : string)]
  | true ->
    let%map.Deferred.Or_error refresh_token =
      try
        Yojson.Safe.from_string body_s
        |> Authorize_response.t_of_yojson
        |> Authorize_response.refresh_token
        |> Deferred.Or_error.return
      with
      | exn ->
        Deferred.Or_error.error_s
          [%message
            "Failed to parse JSON response from authorization request"
              (exn : exn)
              (body_s : string)]
    in
    { client_id; client_secret; refresh_token }
;;

module Access_token_response = struct
  type t = { access_token : string }
  [@@deriving yojson, fields] [@@yojson.allow_extra_fields]
end

let obtain_access_token t =
  let { client_id; client_secret; refresh_token } = t in
  let%bind response, body =
    let uri = Uri.of_string "https://oauth2.googleapis.com/token" in
    let body =
      Body.of_form
        [ "client_id", [ client_id ]
        ; "client_secret", [ client_secret ]
        ; "grant_type", [ "refresh_token" ]
        ; "refresh_token", [ refresh_token ]
        ]
    in
    let headers =
      Header.of_list [ "content-type", "application/x-www-form-urlencoded" ]
    in
    Client.post ~headers ~body uri
  in
  let%bind body_s = Body.to_string body in
  match Cohttp.Response.status response |> Code.code_of_status |> Code.is_success with
  | false ->
    Deferred.Or_error.error_s
      [%message
        "Failed to submit authorization request"
          ~code:(Cohttp.Response.status response |> Code.code_of_status : int)
          ~body:(body_s : string)]
  | true ->
    (try
       let access_token =
         Yojson.Safe.from_string body_s
         |> Access_token_response.t_of_yojson
         |> Access_token_response.access_token
       in
       Log.Global.debug_s [%message "Obtained google-photos access token"];
       Deferred.Or_error.return access_token
     with
    | exn ->
      Deferred.Or_error.error_s
        [%message
          "Failed to parse JSON response from authorization request"
            (exn : exn)
            (body_s : string)])
;;
