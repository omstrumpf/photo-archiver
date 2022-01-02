open! Core
open! Async
open Deferred.Or_error.Let_syntax

let authorize ?output_file ~client_id ~client_secret () =
  let%bind oauth =
    Google_photos.Oauth.authorize_user ~client_id ~client_secret
  in
  let oauth_sexp = [%sexp_of: Google_photos.Oauth.t] oauth in
  match output_file with
  | None ->
      print_s oauth_sexp;
      return ()
  | Some output_file ->
      let%map.Deferred () =
        Writer.save_sexp ~perm:0o600 output_file oauth_sexp
      in
      print_endline "Done! Saved result to output file.";
      Ok ()

let list ~auth_file ?limit () =
  let%bind oauth = Reader.load_sexp auth_file Google_photos.Oauth.t_of_sexp in
  let%bind access_token = Google_photos.Oauth.obtain_access_token oauth in
  let%map photos =
    Google_photos.Api.List_library_contents.submit ~access_token ?limit ()
  in
  print_s
    [%sexp { photos : Google_photos.Api.List_library_contents.Photo.t list }]

let sync_db ?(dry_run = false) ~db_file ~archive_dir () =
  Db.with_db ~db_file ~f:(fun db ->
      let%bind db_photos = Db.all_photos db |> Deferred.return in
      let db_filenames =
        String.Map.to_alist db_photos
        |> List.map ~f:(fun (_id, photo) -> Photo.archive_path photo)
        |> String.Set.of_list
      in
      let%bind archived_filenames =
        Archive.all_archived_files ~archive_dir |> Deferred.ok
      in
      let diff =
        String.Set.symmetric_diff db_filenames archived_filenames
        |> Sequence.to_list
      in
      match List.is_empty diff with
      | true ->
          print_endline "DB and archive are properly synchronized!" |> return
      | false ->
          List.map diff ~f:(fun either ->
              match either with
              | First db_filename ->
                  let%bind.Or_error photo =
                    Db.lookup_photo_by_archive_path db ~archive_path:db_filename
                    |> Or_error.map ~f:(fun x -> Option.value_exn x)
                  in
                  let photo_s = Photo.sexp_of_t photo |> Sexp.to_string_hum in
                  let%bind.Or_error () =
                    let id = Photo.id photo in
                    match dry_run with
                    | true ->
                        print_endline
                          [%string
                            "Photo present in db but not found in archive: \
                             %{photo_s}."];
                        Ok ()
                    | false ->
                        print_endline
                          [%string
                            "Photo present in db but not found in archive: \
                             %{photo_s}. Removing from db."];
                        Db.remove_photo db ~id
                  in
                  Ok ()
              | Second archived_filename ->
                  Or_error.error_string
                    [%string
                      "Photo present in archive but not found in db: \
                       %{archived_filename}"])
          |> Or_error.combine_errors_unit |> Deferred.return)
