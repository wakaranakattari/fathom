(** Repository status from porcelain v1 output.
    Command output is capped to bound latency on large repositories.
    Rename entries resolve to the target side. Quoted paths are
    unquoted. All failures yield empty status. *)

type status = {
  modified : string list;
  added : string list;
  untracked : string list;
}

let empty = { modified = []; added = []; untracked = [] }

(** Runs [cmd] and collects up to [cap] bytes of stdout.
    Stderr is discarded by the caller command line. Process and IO
    errors yield an empty string.
    @return collected output prefix. *)
let read_command cmd cap =
  try
    let ic = Unix.open_process_in cmd in
    let buf = Buffer.create 1024 in
    (try
      while Buffer.length buf < cap do
        let chunk = Bytes.create 1024 in
        let n = input ic chunk 0 1024 in
        if n = 0 then raise End_of_file;
        Buffer.add_subbytes buf chunk 0 n
      done
    with End_of_file -> ());
    let _ = Unix.close_process_in ic in
    Buffer.contents buf
  with Sys_error _ | Unix.Unix_error _ -> ""

(** Resolves [path] against [root] to absolute form.
    Absolute inputs pass through unchanged.
    @return absolute path. *)
let resolve root path =
  if Filename.is_relative path then Filename.concat root path
  else path

let toplevel () =
  let out = read_command "git rev-parse --show-toplevel 2>/dev/null" 4096 in
  let trimmed = String.trim out in
  if trimmed = "" then None
  else Some trimmed

let status () =
  match toplevel () with
  | None -> empty
  | Some root ->
    let out = read_command "git status --porcelain=v1 2>/dev/null" 65536 in
    if out = "" then empty
    else begin
      let modified = ref [] and added = ref [] and untracked = ref [] in
      let lines = String.split_on_char '\n' out in
      List.iter (fun line ->
        if String.length line >= 4 then begin
          let code = String.sub line 0 2 in
          let path = String.trim (String.sub line 3 (String.length line - 3)) in
          (* Rename entries carry the target side after the arrow. *)
          let clean =
            match String.split_on_char '>' path with
            | [ _; target ] -> String.trim target
            | _ -> path
          in
          let quoted =
            let n = String.length clean in
            if n >= 2 && clean.[0] = '"' && clean.[n - 1] = '"' then
              String.sub clean 1 (n - 2)
            else clean
          in
          let abs = resolve root quoted in
          if code = "??" then untracked := abs :: !untracked
          else if code.[0] = 'A' || code.[1] = 'A' then added := abs :: !added
          else if code.[0] = 'M' || code.[1] = 'M' then modified := abs :: !modified
        end
      ) lines;
      { modified = !modified; added = !added; untracked = !untracked }
    end

let boost st path =
  if List.mem path st.modified then 5.0
  else if List.mem path st.added then 3.0
  else if List.mem path st.untracked then 2.0
  else 0.0
