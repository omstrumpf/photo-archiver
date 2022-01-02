open! Core
open! Async
open Deferred.Or_error.Let_syntax
module Config = Config

let authorize ?output_file ~client_id ~client_secret () =
  let%bind oauth = Google_photos.Oauth.authorize_user ~client_id ~client_secret in
  let oauth_sexp = [%sexp_of: Google_photos.Oauth.t] oauth in
  match output_file with
  | None ->
    print_s oauth_sexp;
    return ()
  | Some output_file ->
    let%map.Deferred () = Writer.save_sexp ~perm:0o600 output_file oauth_sexp in
    print_endline "Done! Saved result to output file.";
    Ok ()
;;

let list ?limit { Config.auth_file; _ } =
  let%bind oauth = Reader.load_sexp auth_file Google_photos.Oauth.t_of_sexp in
  let%bind access_token = Google_photos.Oauth.obtain_access_token oauth in
  let%map photos = Google_photos.Api.List_photos.submit ~access_token ?limit () in
  print_s [%sexp { photos : Google_photos.Api.List_photos.Photo.t list }]
;;

let archive ?(dry_run = false) ?limit { Config.auth_file; db_file; archive_dir } =
  let%bind oauth = Reader.load_sexp auth_file Google_photos.Oauth.t_of_sexp in
  let%bind access_token = Google_photos.Oauth.obtain_access_token oauth in
  let%bind photos = Google_photos.Api.List_photos.submit ~access_token () in
  let num_present_photos = ref 0 in
  let num_new_photos = ref 0 in
  let incr x = x := !x + 1 in
  let over_limit () =
    match limit with
    | None -> false
    | Some limit -> !num_new_photos >= limit
  in
  let%map () =
    Db.with_db ~db_file ~f:(fun db ->
        Deferred.Or_error.List.iter photos ~f:(fun photo ->
            if over_limit ()
            then return ()
            else (
              let { Google_photos.Api.List_photos.Photo.id
                  ; name
                  ; created_at
                  ; download_url
                  }
                =
                photo
              in
              let%bind db_photo = Db.lookup_photo db ~id |> Deferred.return in
              match db_photo with
              | Some _ ->
                incr num_present_photos;
                (* This photo is already archived *) return ()
              | None ->
                let created_at_date =
                  Time_ns.to_date ~zone:(force Time_ns.Zone.local) created_at
                in
                (match dry_run with
                | true ->
                  print_endline
                    [%string "Would download %{name} (%{created_at_date#Date})."];
                  return ()
                | false ->
                  print_endline
                    [%string "Downloading %{name} (%{created_at_date#Date})..."];
                  let archive_path = Archive.archive_path ~name ~created_at in
                  let photo = { Db.Photo.id; name; created_at; archive_path } in
                  (match%bind.Deferred
                     Downloader.download
                       ~from_url:download_url
                       ~to_file:(archive_dir ^/ archive_path)
                   with
                  | Error e ->
                    Deferred.Or_error.error_s
                      [%message
                        "Failed to download photo"
                          ~photo:(photo : Db.Photo.t)
                          ~download_error:(e : Error.t)]
                  | Ok () ->
                    let%map () = Db.insert_photo db photo |> Deferred.return in
                    incr num_new_photos)))))
  in
  print_endline
    [%string
      "Archiving complete! %{!num_present_photos#Int} photos were previously archived, \
       and %{!num_new_photos#Int} new ones were downloaded."]
;;

let sync_db ?(dry_run = false) { Config.db_file; archive_dir; _ } =
  Db.with_db ~db_file ~f:(fun db ->
      let%bind db_photos = Db.all_photos db |> Deferred.return in
      let db_filenames =
        String.Map.to_alist db_photos
        |> List.map ~f:(fun (_id, photo) -> Db.Photo.archive_path photo)
        |> String.Set.of_list
      in
      let%bind archived_filenames =
        Archive.all_archived_files ~archive_dir |> Deferred.ok
      in
      let diff =
        String.Set.symmetric_diff db_filenames archived_filenames |> Sequence.to_list
      in
      match List.is_empty diff with
      | true -> print_endline "DB and archive are properly synchronized!" |> return
      | false ->
        List.map diff ~f:(fun either ->
            match either with
            | First db_filename ->
              let%bind.Or_error photo =
                Db.lookup_photo_by_archive_path db ~archive_path:db_filename
                |> Or_error.map ~f:(fun x -> Option.value_exn x)
              in
              let photo_s = Db.Photo.sexp_of_t photo |> Sexp.to_string_hum in
              let%bind.Or_error () =
                let id = Db.Photo.id photo in
                match dry_run with
                | true ->
                  print_endline
                    [%string "Photo present in db but not found in archive: %{photo_s}."];
                  Ok ()
                | false ->
                  print_endline
                    [%string
                      "Photo present in db but not found in archive: %{photo_s}. \
                       Removing from db."];
                  Db.remove_photo db ~id
              in
              Ok ()
            | Second archived_filename ->
              Or_error.error_string
                [%string
                  "Photo present in archive but not found in db: %{archived_filename}"])
        |> Or_error.combine_errors_unit
        |> Deferred.return)
;;
