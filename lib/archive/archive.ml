open! Core
open! Async

let ignore_filenames = [ ".DS_Store" ] |> String.Set.of_list

let all_archived_files ~archive_dir =
  let rec recursive_ls path =
    match%bind Sys.is_directory_exn path with
    | false -> (
        match Set.mem ignore_filenames (Filename.basename path) with
        | true -> return []
        | false -> return [ path ])
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
