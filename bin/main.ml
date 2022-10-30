open! Core
open! Async

let log_param =
  let%map_open.Command () = Log.Global.set_level_via_param ()
  and log_file =
    flag "-log-file" (optional Filename_unix.arg_type) ~doc:"FILE write logs to FILE"
  in
  match log_file with
  | None -> ()
  | Some filename -> Log.Global.set_output [ Log.Output.file `Sexp_hum ~filename ]
;;

let log_error (f : 'a Deferred.Or_error.t) () : 'a Deferred.Or_error.t =
  match%map f with
  | Ok x -> Ok x
  | Error e ->
    Log.Global.error_s (Error.sexp_of_t e);
    Error e
;;

let cmd_authorize =
  Command.async_or_error
    ~summary:"Get an OAuth2 token from Google"
    (let%map_open.Command client_id =
       flag "-client-id" (required string) ~doc:"Google API Client ID of this app"
     and client_secret =
       flag "-client-secret" (required string) ~doc:"Google API Client Secret of this app"
     and output_file =
       flag
         "-output-file"
         (optional Filename_unix.arg_type)
         ~doc:"FILE save oauth tokens to FILE"
     and () = log_param in
     log_error (Photo_archiver.authorize ?output_file ~client_id ~client_secret ()))
;;

let cmd_gen_config =
  Command.async
    ~summary:"Generate a config file"
    (let%map_open.Command output_file =
       flag "-output-file" (optional Filename_unix.arg_type) ~doc:"FILE write config to FILE"
     and config = Photo_archiver.Config.arg_type
     and () = log_param in
     fun () ->
       match output_file with
       | None ->
         let stdout = force Writer.stdout in
         Writer.write_sexp stdout ([%sexp_of: Photo_archiver.Config.t] config);
         Writer.flushed stdout
       | Some output_file -> Photo_archiver.Config.save ~to_file:output_file config)
;;

let config_file_param =
  let open Command.Param in
  flag "-config-file" (required Filename_unix.arg_type) ~doc:"FILE config file"
;;

let dry_run_param =
  let open Command.Param in
  flag "-dry-run" no_arg ~doc:"don't modify database"
;;

let cmd_list =
  Command.async_or_error
    ~summary:"List all photos on google photos"
    (let%map_open.Command config_file = config_file_param
     and limit = flag "-limit" (optional int) ~doc:"Stop after listing this many photos"
     and () = log_param in
     log_error
       (let%bind.Deferred.Or_error config = Photo_archiver.Config.load config_file in
        Photo_archiver.list ?limit config))
;;

let cmd_archive =
  Command.async_or_error
    ~summary:"Download missing photos"
    (let%map_open.Command config_file = config_file_param
     and dry_run = dry_run_param
     and limit =
       flag "-limit" (optional int) ~doc:"Stop after processing this many photos"
     and () = log_param in
     log_error
       (let%bind.Deferred.Or_error config = Photo_archiver.Config.load config_file in
        Photo_archiver.archive ~dry_run ?limit config))
;;

let cmd_sync_db =
  Command.async_or_error
    ~summary:"Synchronize the database with files on disk"
    (let%map_open.Command config_file = config_file_param
     and dry_run = dry_run_param
     and () = log_param in
     log_error
       (let%bind.Deferred.Or_error config = Photo_archiver.Config.load config_file in
        Photo_archiver.sync_db ~dry_run config))
;;

let command =
  Command.group
    ~summary:"Maintains a local archive of photos from google-photos"
    [ "authorize", cmd_authorize
    ; "gen-config", cmd_gen_config
    ; "list", cmd_list
    ; "archive", cmd_archive
    ; "sync-db", cmd_sync_db
    ]
;;

let () = Command_unix.run command
