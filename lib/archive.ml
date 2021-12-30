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
