open! Core
open! Async
open Cohttp
open Cohttp_async

let follow_redirects ?(max_redirects = 10) uri f =
  (* Copied from https://github.com/mirage/ocaml-cohttp#dealing-with-redirects *)
  let seen_uris = String.Hash_set.create () in
  let rec loop ~max_redirects uri =
    Hash_set.add seen_uris (Uri.to_string uri);
    let%bind ((response, response_body) as res) = f uri in
    let status_code = Response.status response |> Code.code_of_status in
    if Code.is_redirection status_code then (
      match Response.headers response |> Header.get_location with
      | Some new_uri when Uri.to_string new_uri |> Hash_set.mem seen_uris ->
          return res
      | Some new_uri ->
          if max_redirects > 0 then
            (* Cohttp leaks connections if we don't drain the response body *)
            Body.drain response_body >>= fun () ->
            loop ~max_redirects:(max_redirects - 1) new_uri
          else (
            Log.Global.debug ~tags:[]
              "Ignoring %d redirect from %s to %s: redirect limit exceeded"
              status_code (Uri.to_string uri) (Uri.to_string new_uri);
            return res)
      | None ->
          Log.Global.debug ~tags:[]
            "Ignoring %d redirect from %s: there is no Location header"
            status_code (Uri.to_string uri);
          return res)
    else return res
  in
  loop ~max_redirects uri

let download_photo ~from_url ~to_file =
  let%bind response, body =
    follow_redirects (Uri.of_string from_url) Cohttp_async.Client.get
  in
  match
    Cohttp.Response.status response
    |> Cohttp.Code.code_of_status |> Cohttp.Code.is_success
  with
  | false ->
      let%bind body_s = Cohttp_async.Body.to_string body in
      Deferred.Or_error.error_s
        [%message
          "Failed to download photo"
            ~download_url:(from_url : string)
            ~code:
              (Cohttp.Response.status response |> Cohttp.Code.code_of_status
                : int)
            ~body:(body_s : string)]
  | true ->
      Monitor.try_with_or_error (fun () ->
          let pipe = Cohttp_async.Body.to_pipe body in
          let%bind () = Unix.mkdir ~p:() (Filename.dirname to_file) in
          Writer.with_file ~append:false to_file ~f:(fun writer ->
              let%bind () =
                Pipe.iter_without_pushback pipe ~f:(Writer.write writer)
              in
              Writer.flushed writer))
