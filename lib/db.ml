open! Core
open! Async

type t = Sqlite3.db

let parse_db_row row =
  match Array.to_list row with
  | [ id; name; archive_path; created_at ] ->
      let%map.Or_error created_at =
        Or_error.try_with (fun () -> Time_ns.of_string created_at)
      in
      { Photo.id; name; archive_path; created_at }
  | _ ->
      Or_error.error_s
        [%message "Database error: failed to parse row" (row : string array)]

let or_error_of_rc rc =
  if Sqlite3.Rc.is_success rc then Ok ()
  else
    Or_error.error_string [%string "Sqlite3 error: %{Sqlite3.Rc.to_string rc}"]

let create_table_if_not_found t () =
  Sqlite3.exec t
    "CREATE TABLE IF NOT EXISTS photos (id string PRIMARY KEY, name string NOT \
     NULL, archive_path string NOT NULL UNIQUE, created_at string NOT NULL);"
  |> or_error_of_rc

let with_db ~db_file ~f =
  let t = Sqlite3.db_open ~mutex:`FULL db_file in
  let%map result =
    Monitor.try_with_join_or_error (fun () ->
        let%bind.Deferred.Or_error () =
          create_table_if_not_found t () |> return
        in
        f t)
  in
  match Sqlite3.db_close t with
  | false -> Or_error.error_s [%message "Failed to close sqlite3 database"]
  | true -> result

let insert_photo t photo =
  let { Photo.id; name; archive_path; created_at } = photo in
  let created_at = Time_ns.to_string created_at in
  Sqlite3.exec t
    [%string
      "INSERT INTO photos (id, name, archive_path, created_at) VALUES \
       ('%{id}', '%{name}', '%{archive_path}', '%{created_at}');"]
  |> or_error_of_rc

let lookup_photo t ~id =
  let results = ref [] in
  let%bind.Or_error () =
    Sqlite3.exec_not_null_no_headers t
      ~cb:(fun row -> results := !results @ [ row ])
      [%string "SELECT * FROM photos WHERE id='%{id}' LIMIT 1"]
    |> or_error_of_rc
  in
  match !results with
  | [] -> Ok None
  | [ row ] ->
      let%map.Or_error photo = parse_db_row row in
      Some photo
  | _ ->
      Or_error.error_s
        [%message "Database invariant violated: id not unique" (id : string)]

let lookup_photo_by_archive_path t ~archive_path =
  let results = ref [] in
  let%bind.Or_error () =
    Sqlite3.exec_not_null_no_headers t
      ~cb:(fun row -> results := !results @ [ row ])
      [%string
        "SELECT * FROM photos WHERE archive_path='%{archive_path}' LIMIT 1"]
    |> or_error_of_rc
  in
  match !results with
  | [] -> Ok None
  | [ row ] ->
      let%map.Or_error photo = parse_db_row row in
      Some photo
  | _ ->
      Or_error.error_s
        [%message
          "Database invariant violated: archive_path not unique"
            (archive_path : string)]

let all_photos t =
  let results = ref [] in
  let%bind.Or_error () =
    Sqlite3.exec_not_null_no_headers t
      ~cb:(fun row -> results := !results @ [ row ])
      [%string "SELECT * FROM photos"]
    |> or_error_of_rc
  in
  let%bind.Or_error photos_list =
    List.map !results ~f:parse_db_row |> Or_error.combine_errors
  in
  List.map photos_list ~f:(fun photo -> (Photo.id photo, photo))
  |> String.Map.of_alist_or_error

let remove_photo t ~id =
  Sqlite3.exec t [%string "DELETE FROM photos WHERE id='%{id}' LIMIT 1"]
  |> or_error_of_rc
