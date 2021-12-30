open! Core
open! Async

let cmd_authorize =
  Command.async_or_error ~summary:"Get an OAuth2 token from Google"
    (let%map_open.Command client_id =
       flag "-client-id" (required string)
         ~doc:"Google API Client ID of this app"
     and client_secret =
       flag "-client-secret" (required string)
         ~doc:"Google API Client Secret of this app"
     and output_file =
       flag "-output-file"
         (optional Filename.arg_type)
         ~doc:"FILE save oauth tokens to FILE"
     in
     fun () ->
       Photo_archiver.authorize ?output_file ~client_id ~client_secret ())

let cmd_list =
  Command.async_or_error ~summary:"List all photos on google photos"
    (let%map_open.Command auth_file =
       flag "-auth-file"
         (required Filename.arg_type)
         ~doc:"Path to file containing auth tokens"
     and max_photos =
       flag "-max-photos" (optional int)
         ~doc:"Stop after listing this many photos"
     in
     fun () -> Photo_archiver.list ~auth_file ?max_photos ())

let cmd_sync_db =
  Command.async_or_error ~summary:"Synchronize the database with files on disk"
    (let%map_open.Command db_file =
       flag "-database-file"
         (required Filename.arg_type)
         ~doc:"Path to sqlite3 database file"
     and archive_dir =
       flag "-archive-directory"
         (required Filename.arg_type)
         ~doc:"Path to photo archive directory"
     in
     fun () -> Photo_archiver.sync_db ~db_file ~archive_dir ())

let command =
  Command.group ~summary:"TODO"
    [
      ("authorize", cmd_authorize); ("list", cmd_list); ("sync-db", cmd_sync_db);
    ]

let () = Command.run command
