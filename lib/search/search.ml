(** Bounded content search with line granularity.
    File size and binary prefix gates precede line reads. Scans stop
    at the match limit through an internal exception for control flow.
    Results accumulate in reverse and restore scan order on return. *)

type line_match = {
  path : string;
  line_no : int;
  col : int;
  line : string;
}

(** Size bound for content scans in bytes. *)
let max_file_size = 1048576

(** Retained line length bound in bytes. *)
let max_line_len = 500

(** Case folding over ASCII letters.
    Non-ASCII bytes pass through unchanged.
    @return folded string. *)
let lower_ascii s =
  String.map (fun c ->
    if c >= 'A' && c <= 'Z' then Char.chr (Char.code c + 32) else c
  ) s

(** Locates lowercase [query] in lowercase [text].
    Callers fold both sides before invocation.
    @return byte offset of the first occurrence, or None. *)
let find_in_line ~query ~text =
  let n = String.length text and m = String.length query in
  if m = 0 || m > n then None
  else
    let rec outer i =
      if i + m > n then None
      else
        let rec inner j =
          if j = m then true
          else if text.[i + j] <> query.[j] then false
          else inner (j + 1)
        in
        if inner 0 then Some i else outer (i + 1)
    in
    outer 0

let file_is_binary path =
  try
    let ic = open_in_bin path in
    let len =
      try in_channel_length ic with Sys_error _ -> 0
    in
    let bound = min len 8192 in
    if bound <= 0 then (close_in ic; false)
    else
      let buf = Bytes.create bound in
      really_input ic buf 0 bound;
      close_in ic;
      (try ignore (Bytes.index buf '\000'); true with Not_found -> false)
  with Sys_error _ | End_of_file | Invalid_argument _ -> true

(** Tests the size gate without content reads.
    @return true for regular files within the size bound. *)
let size_ok path =
  try
    let stats = Unix.stat path in
    stats.Unix.st_size >= 0 && stats.Unix.st_size <= max_file_size
  with Unix.Unix_error _ -> false

let contains_query ~query ~path =
  if query = "" then false
  else if not (size_ok path) then false
  else if file_is_binary path then false
  else
    try
      let ic = open_in_bin path in
      let q = lower_ascii query in
      let rec loop () =
        let line = input_line ic in
        let t = lower_ascii line in
        match find_in_line ~query:q ~text:t with
        | Some _ -> close_in ic; true
        | None -> loop ()
      in
      (try loop () with End_of_file -> close_in ic; false)
    with Sys_error _ -> false

(** Truncates [line] to the retained length bound.
    Longer lines keep a prefix with an ellipsis marker.
    @return truncated line. *)
let truncate_line line =
  if String.length line <= max_line_len then line
  else String.sub line 0 max_line_len ^ "..."

let search ~query ~paths ~limit =
  if query = "" || limit <= 0 then []
  else
    let q = lower_ascii query in
    let acc = ref [] in
    let count = ref 0 in
    (try
      List.iter (fun path ->
        if !count >= limit then raise Exit;
        if not (size_ok path) then ()
        else if file_is_binary path then ()
        else
          (try
            let ic = open_in_bin path in
            (try
              let line_no = ref 0 in
              while !count < limit do
                let line = input_line ic in
                incr line_no;
                let t = lower_ascii line in
                (match find_in_line ~query:q ~text:t with
                | Some col ->
                  acc := { path; line_no = !line_no; col; line = truncate_line line } :: !acc;
                  incr count
                | None -> ())
              done;
              close_in ic
            with End_of_file -> close_in_noerr ic)
          with Sys_error _ -> ())
      ) paths
    with Exit -> ());
    List.rev !acc
