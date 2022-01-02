open! Core
open! Async
open Cohttp
open Cohttp_async

let base_headers ~access_token =
  Cohttp.Header.of_list
    [ "content-type", "application/json"; "authorization", "Bearer " ^ access_token ]
;;

module Media_metadata = struct
  module Photo = struct
    type t =
      { camera_make : string option [@yojson.option] [@key "cameraMake"]
      ; camera_model : string option [@yojson.option] [@key "cameraModel"]
      }
    [@@deriving fields, sexp, yojson] [@@yojson.allow_extra_fields]
  end

  module Video = struct
    type t = { status : string }
    [@@deriving fields, sexp, yojson] [@@yojson.allow_extra_fields]
  end

  type t =
    { creation_time : string [@key "creationTime"]
    ; width : string option [@yojson.option]
    ; height : string option [@yojson.option]
    ; photo : Photo.t option [@yojson.option]
    ; video : Video.t option [@yojson.option]
    }
  [@@deriving fields, sexp, yojson] [@@yojson.allow_extra_fields]
end

module Media_item = struct
  type t =
    { id : string
    ; filename : string
    ; base_url : string [@key "baseUrl"]
    ; description : string option [@yojson.option]
    ; product_url : string option [@yojson.option] [@key "productUrl"]
    ; mime_type : string option [@yojson.option] [@key "mimeType"]
    ; media_metadata : Media_metadata.t [@key "mediaMetadata"]
    }
  [@@deriving fields, sexp, yojson] [@@yojson.allow_extra_fields]
end

module List_photos = struct
  module Photo = struct
    type t =
      { id : string
      ; name : string
      ; created_at : Time_ns.t
      ; download_url : string
      }
    [@@deriving fields, sexp_of]

    let of_media_item media_item =
      let { Media_item.id
          ; media_metadata
          ; filename
          ; base_url
          ; description = _
          ; product_url = _
          ; mime_type = _
          }
        =
        media_item
      in
      let { Media_metadata.creation_time; video = video_metadata; _ } = media_metadata in
      let%map.Or_error created_at =
        Or_error.try_with (fun () ->
            Time_ns.of_string_gen ~if_no_timezone:`Local creation_time)
      in
      let download_url =
        let suffix =
          match video_metadata with
          | Some _ -> "dv"
          | None -> "d"
        in
        [%string "%{base_url}=%{suffix}"]
      in
      { id; name = filename; created_at; download_url }
    ;;
  end

  module Response = struct
    type t =
      { media_items : Media_item.t list [@key "mediaItems"] [@default []]
      ; next_page_token : string option [@key "nextPageToken"] [@yojson.option]
      }
    [@@deriving yojson]
  end

  let max_page_size = 100

  let uri ?(page_size = max_page_size) ?page_token () =
    let query =
      let page_size = [ "pageSize", [ [%string "%{page_size#Int}"] ] ] in
      let page_token =
        match page_token with
        | None -> []
        | Some page_token -> [ "pageToken", [ page_token ] ]
      in
      page_size @ page_token
    in
    Uri.make
      ~scheme:"https"
      ~host:"photoslibrary.googleapis.com"
      ~path:"/v1/mediaItems"
      ~query
      ()
  ;;

  let rec submit_paged ~access_token ?limit acc page_token =
    let uri = uri ?page_token () in
    let%bind response, body = Client.get ~headers:(base_headers ~access_token) uri in
    let%bind body_s = Body.to_string body in
    match Cohttp.Response.status response |> Code.code_of_status |> Code.is_success with
    | false ->
      Deferred.Or_error.error_s
        [%message
          "Failed to submit List_library_contents request"
            ~code:(Cohttp.Response.status response |> Code.code_of_status : int)
            ~body:(body_s : string)]
    | true ->
      let%bind.Deferred.Or_error response =
        try
          Yojson.Safe.from_string body_s
          |> Response.t_of_yojson
          |> Deferred.Or_error.return
        with
        | exn ->
          Deferred.Or_error.error_s
            [%message
              "Failed to parse JSON response from List_library_contents request"
                (exn : exn)
                (body_s : string)]
      in
      let { Response.media_items; next_page_token } = response in
      let new_acc = acc @ media_items in
      (match next_page_token with
      | None -> Deferred.Or_error.return new_acc
      | Some next_page_token ->
        let submit_next_page () =
          submit_paged ~access_token ?limit new_acc (Some next_page_token)
        in
        (match limit with
        | None -> submit_next_page ()
        | Some limit ->
          if List.length new_acc < limit
          then submit_next_page ()
          else
            List.drop (List.rev new_acc) (List.length new_acc - limit)
            |> List.rev
            |> Deferred.Or_error.return))
  ;;

  let submit ~access_token ?limit () =
    let%bind.Deferred.Or_error media_items = submit_paged ~access_token ?limit [] None in
    List.map media_items ~f:Photo.of_media_item |> Or_error.combine_errors |> return
  ;;
end
