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

let cmd_config =
  Command.async ~summary:"Generate a config file"
    (let%map_open.Command output_file =
       flag "-output-file"
         (optional Filename.arg_type)
         ~doc:"FILE write conbfig to FILE"
     and config = Photo_archiver.Config.arg_type in
     fun () ->
       match output_file with
       | None ->
           let stdout = force Writer.stdout in
           Writer.write_sexp stdout ([%sexp_of: Photo_archiver.Config.t] config);
           Writer.flushed stdout
       | Some output_file ->
           Photo_archiver.Config.save ~to_file:output_file config)

let cmd_list =
  Command.async_or_error ~summary:"List all photos on google photos"
    (let%map_open.Command config = Photo_archiver.Config.arg_type
     and limit =
       flag "-limit" (optional int) ~doc:"Stop after listing this many photos"
     in
     fun () -> Photo_archiver.list ?limit config)

let cmd_sync_db =
  Command.async_or_error ~summary:"Synchronize the database with files on disk"
    (let%map_open.Command config = Photo_archiver.Config.arg_type
     and dry_run = flag "-dry-run" no_arg ~doc:"don't modify database" in
     fun () -> Photo_archiver.sync_db ~dry_run config)

let command =
  Command.group ~summary:"TODO"
    [
      ("authorize", cmd_authorize); ("list", cmd_list); ("sync-db", cmd_sync_db);
    ]

let () = Command.run command
