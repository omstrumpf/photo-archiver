open! Core
open! Async

let all_archived_files ~archive_dir =
  let rec recursive_ls path =
    match%bind Sys.is_directory_exn path with
    | false -> return [ path ]
    | true ->
        Sys.ls_dir path
        >>= Deferred.List.concat_map ~f:(fun child ->
                recursive_ls (path ^/ child))
  in
  recursive_ls archive_dir
  >>| List.map ~f:(String.chop_prefix_exn ~prefix:archive_dir)
  >>| String.Set.of_list

let archive_path ~name ~created_at =
  let date = Time_ns.to_date created_at ~zone:(force Time_ns.Zone.local) in
  let year = Printf.sprintf "%04d" (Date.year date) in
  let month = Printf.sprintf "%02d" (Date.month date |> Month.to_int) in
  year ^/ month ^/ name

let download_photo ~archive_dir ~id ~name ~created_at ~download_url =
  let archive_path = archive_path ~name ~created_at in
  match%map
    Downloader.download_photo ~from_url:download_url
      ~to_file:(archive_dir ^/ archive_path)
  with
  | Error e ->
      Or_error.error_s
        [%message
          "Failed to download photo"
            ~id:(id : string)
            ~name:(name : string)
            ~created_at:(created_at : Time_ns.t)
            ~download_error:(e : Error.t)]
  | Ok () -> Ok { Photo.id; name; created_at; archive_path }
