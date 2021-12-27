open! Core
open! Async

let authorize ?output_file ~client_id ~client_secret () =
  let%bind.Deferred.Or_error oauth =
    Google_photos.Oauth.authorize_user ~client_id ~client_secret
  in
  let oauth_sexp = [%sexp_of: Google_photos.Oauth.t] oauth in
  match output_file with
  | None ->
      print_s oauth_sexp;
      Deferred.Or_error.return ()
  | Some output_file ->
      let%map () = Writer.save_sexp ~perm:0o600 output_file oauth_sexp in
      print_endline "Done! Saved result to output file.";
      Ok ()

let list ~auth_file =
  let%bind.Deferred.Or_error oauth =
    Reader.load_sexp auth_file Google_photos.Oauth.t_of_sexp
  in
  let%bind.Deferred.Or_error access_token =
    Google_photos.Oauth.obtain_access_token oauth
  in
  let%map.Deferred.Or_error photos =
    Google_photos.Api.List_library_contents.submit ~access_token ()
  in
  print_s [%sexp { photos : Google_photos.Types.Media_item.t list }]
