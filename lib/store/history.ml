(** File backed access history.
    Table entries map absolute paths to access counts with last access
    timestamps. Persistence is tab separated text. Corrupt lines are
    skipped on load. Writes are total and silent. *)

type entry = {
  count : int;
  last_seen : float;
}

type t = (string, entry) Hashtbl.t

let empty : t = Hashtbl.create 128

(** Parses a history line of [path] TAB [count] TAB [timestamp] form.
    Empty paths and negative counts are rejected.
    @return path with entry, or None for malformed input. *)
let parse_line line =
  match String.split_on_char '\t' line with
  | [ path; count_s; time_s ] ->
    (try
      let count = int_of_string count_s in
      let last_seen = float_of_string time_s in
      if path = "" || count < 0 then None
      else Some (path, { count; last_seen })
    with Failure _ -> None)
  | _ -> None

let load path =
  let table : t = Hashtbl.create 256 in
  (try
    let ic = open_in path in
    (try
      while true do
        let line = input_line ic in
        match parse_line line with
        | Some (p, e) -> Hashtbl.replace table p e
        | None -> ()
      done
    with End_of_file -> close_in ic)
  with Sys_error _ -> ());
  table

let record (t : t) path =
  let now = Unix.gettimeofday () in
  (match Hashtbl.find_opt t path with
  | Some e -> Hashtbl.replace t path { count = e.count + 1; last_seen = now }
  | None -> Hashtbl.add t path { count = 1; last_seen = now });
  t

(** Creates ancestor directories of [path] as needed.
    Errors are ignored since history is auxiliary data.
    @return unit. *)
let ensure_parent path =
  let dir = Filename.dirname path in
  let rec make d =
    if d = "" || d = "." || Sys.file_exists d then ()
    else begin
      make (Filename.dirname d);
      try Unix.mkdir d 0o755 with Unix.Unix_error _ -> ()
    end
  in
  make dir

let save (t : t) path =
  try
    ensure_parent path;
    let oc = open_out path in
    Hashtbl.iter (fun p e ->
      Printf.fprintf oc "%s\t%d\t%f\n" p e.count e.last_seen
    ) t;
    close_out oc
  with Sys_error _ -> ()

(** Boost composition with age decay.
    Recency decays over days from last access. Frequency contributes a
    logarithmic term in access count, which bounds dominance of stale
    frequent paths. *)
let boost (t : t) path =
  match Hashtbl.find_opt t path with
  | None -> 0.0
  | Some e ->
    let now = Unix.gettimeofday () in
    let age = max 0.0 (now -. e.last_seen) in
    let recency = 8.0 /. (1.0 +. age /. 86400.0) in
    let freq = log (1.0 +. float_of_int e.count) in
    recency +. freq

let default_path () =
  let base =
    match Sys.getenv_opt "XDG_CACHE_HOME" with
    | Some dir when dir <> "" -> dir
    | _ ->
      (match Sys.getenv_opt "HOME" with
      | Some home -> Filename.concat home ".cache"
      | None -> ".")
  in
  Filename.concat (Filename.concat base "fathom") "history.tsv"
