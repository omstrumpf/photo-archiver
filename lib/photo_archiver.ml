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

let list ~auth_file ?max_photos () =
  let%bind oauth = Reader.load_sexp auth_file Google_photos.Oauth.t_of_sexp in
  let%bind access_token = Google_photos.Oauth.obtain_access_token oauth in
  let%map photos =
    Google_photos.Api.List_library_contents.submit ~access_token
      ?max_items:max_photos ()
  in
  print_s [%sexp { photos : Google_photos.Types.Media_item.t list }]

let sync_db ~db_file ~archive_dir:_ () =
  let%bind _db_photos =
    Db.with_db ~db_file ~f:(fun db -> Db.all_photos db |> Deferred.return)
  in
  return ()
