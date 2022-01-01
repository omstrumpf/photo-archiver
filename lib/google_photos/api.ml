open! Core
open! Async
open Cohttp
open Cohttp_async
open Types

let base_headers ~access_token =
  Cohttp.Header.of_list
    [
      ("content-type", "application/json");
      ("authorization", "Bearer " ^ access_token);
    ]

module List_library_contents = struct
  module Response = struct
    type t = {
      media_items : Media_item.t list; [@key "mediaItems"] [@default []]
      next_page_token : string option; [@key "nextPageToken"] [@yojson.option]
    }
    [@@deriving yojson]
  end

  let max_page_size = 100

  let uri ?(page_size = max_page_size) ?page_token () =
    let query =
      let page_size = [ ("pageSize", [ [%string "%{page_size#Int}"] ]) ] in
      let page_token =
        match page_token with
        | None -> []
        | Some page_token -> [ ("pageToken", [ page_token ]) ]
      in
      page_size @ page_token
    in
    Uri.make ~scheme:"https" ~host:"photoslibrary.googleapis.com"
      ~path:"/v1/mediaItems" ~query ()

  let rec submit_paged ~access_token ?limit acc page_token =
    let uri = uri ?page_token () in
    let%bind response, body =
      Client.get ~headers:(base_headers ~access_token) uri
    in
    let%bind body_s = Body.to_string body in
    match
      Cohttp.Response.status response |> Code.code_of_status |> Code.is_success
    with
    | false ->
        Deferred.Or_error.error_s
          [%message
            "Failed to submit List_library_contents request"
              ~code:
                (Cohttp.Response.status response |> Code.code_of_status : int)
              ~body:(body_s : string)]
    | true -> (
        let%bind.Deferred.Or_error response =
          try
            Yojson.Safe.from_string body_s
            |> Response.t_of_yojson |> Deferred.Or_error.return
          with exn ->
            Deferred.Or_error.error_s
              [%message
                "Failed to parse JSON response from List_library_contents \
                 request"
                  (exn : exn)
                  (body_s : string)]
        in
        let { Response.media_items; next_page_token } = response in
        let new_acc = acc @ media_items in
        match next_page_token with
        | None -> Deferred.Or_error.return new_acc
        | Some next_page_token -> (
            let submit_next_page () =
              submit_paged ~access_token ?limit new_acc (Some next_page_token)
            in
            match limit with
            | None -> submit_next_page ()
            | Some limit ->
                if List.length new_acc < limit then submit_next_page ()
                else
                  List.drop (List.rev new_acc) (List.length new_acc - limit)
                  |> List.rev |> Deferred.Or_error.return))

  let submit ~access_token ?limit () = submit_paged ~access_token ?limit [] None
end
