(** Deterministic directory traversal.
    Directory reads sort before descent, hence enumeration order is
    stable across runs on identical trees. Pruning precedes recursion
    to bound stack use. Ignore patterns accumulate from each visited
    directory downward. *)

(** Directory names excluded in every visited directory. *)
let pruned_names = [ ".git"; "_build"; "node_modules"; ".hg"; "_opam"; ".lsp" ]

(* Returns true if [name] is a pruned directory entry. *)
let is_pruned name =
  List.mem name pruned_names

(** Tests hidden entry status. Single and double dots are excluded
    from the definition.
    @return true for dot-prefixed names. *)
let is_hidden name =
  String.length name > 0 && name.[0] = '.' && name <> "." && name <> ".."

(** Reads ignore patterns from a single [file] in [dir].
    Blank lines, comment lines, and negation lines are skipped. Only
    prefix, basename, and suffix rules apply. Missing files contribute
    no patterns.
    @return pattern list in file order. *)
let read_ignore_file dir file =
  let path = Filename.concat dir file in
  try
    let ic = open_in path in
    let rec loop acc =
      try
        let line = String.trim (input_line ic) in
        if line = "" then loop acc
        else if line.[0] = '#' then loop acc
        else if line.[0] = '!' then loop acc
        else loop (line :: acc)
      with End_of_file ->
        close_in ic;
        acc
    in
    loop []
  with Sys_error _ -> []

(** Collects patterns from standard ignore files in [dir].
    Sources are [.gitignore], [.ignore], and [.fdignore]. The
    [no_ignore] flag yields an empty list.
    @return combined pattern list. *)
let read_patterns ~no_ignore dir =
  if no_ignore then []
  else
    read_ignore_file dir ".gitignore"
    @ read_ignore_file dir ".ignore"
    @ read_ignore_file dir ".fdignore"

(** Tests [path] against ignore [patterns].
    Trailing slash patterns match directory basenames. Remaining
    patterns match basename equality or path suffix. Star patterns
    carry no meaning and never match.
    @return true on first matching pattern. *)
let is_ignored patterns path =
  let base = Filename.basename path in
  List.exists (fun pat ->
    if pat = "" then false
    else if pat.[String.length pat - 1] = '/' then
      let prefix = String.sub pat 0 (String.length pat - 1) in
      base = prefix
    else if String.contains pat '*' then false
    else base = pat || Filename.check_suffix path pat
  ) patterns

(* Collects files under [root] into [acc]. Order of visit is sorted
   to keep output deterministic. Symlinks are listed but not followed
   when they resolve to directories. Subdirectory ignore files extend
   parent patterns. *)
let rec collect ~hidden ~no_ignore ~patterns root acc =
  let entries =
    try Sys.readdir root with Sys_error _ -> [||]
  in
  Array.sort String.compare entries;
  Array.fold_left (fun acc entry ->
    if is_pruned entry then acc
    else if (not hidden) && is_hidden entry then acc
    else
      let full = Filename.concat root entry in
      if is_ignored patterns full then acc
      else
        (try
          let stats = Unix.lstat full in
          match stats.Unix.st_kind with
          | Unix.S_DIR ->
            let sub =
              if no_ignore then []
              else
                read_ignore_file full ".gitignore"
                @ read_ignore_file full ".ignore"
                @ read_ignore_file full ".fdignore"
            in
            collect ~hidden ~no_ignore ~patterns:(sub @ patterns) full acc
          | Unix.S_REG -> full :: acc
          | Unix.S_LNK ->
            (try
              let target = Unix.stat full in
              if target.Unix.st_kind = Unix.S_DIR then acc
              else full :: acc
            with Unix.Unix_error _ -> acc)
          | _ -> acc
        with Unix.Unix_error _ -> acc)
  ) acc entries

(* Normalizes [p] to an absolute path without resolving symlinks.
   Invariant: result has no trailing slash except for root. Dot segments
   for the current directory are removed for stable display. *)
let normalize p =
  let base =
    if Filename.is_relative p then Filename.concat (Sys.getcwd ()) p
    else p
  in
  let rec strip s =
    let marker = "/./" in
    let n = String.length s and m = String.length marker in
    let rec find i =
      if i + m > n then None
      else if String.sub s i m = marker then Some i
      else find (i + 1)
    in
    match find 0 with
    | None -> s
    | Some i ->
      let before = String.sub s 0 i in
      let after = String.sub s (i + 2) (n - i - 2) in
      strip (before ^ after)
  in
  strip base

(* Walks a single root. *)
let walk_one ~hidden ~no_ignore root =
  let patterns = read_patterns ~no_ignore root in
  let files = collect ~hidden ~no_ignore ~patterns root [] in
  List.map normalize files

let walk_ex ~hidden ~no_ignore roots =
  let per_root =
    match roots with
    | [] -> []
    | [ single ] -> [ walk_one ~hidden ~no_ignore single ]
    | multiple ->
      (* Parallel walk over roots with Domains. Fallback to
         sequential on join failure. Each domain returns one list. *)
      let domains =
        List.map (fun root ->
          Domain.spawn (fun () -> walk_one ~hidden ~no_ignore root)
        ) multiple
      in
      List.map Domain.join domains
  in
  let files = List.concat per_root in
  List.sort_uniq String.compare files

let walk roots =
  walk_ex ~hidden:false ~no_ignore:false roots

(* Converts absolute path to display form. *)
let to_display ~absolute path =
  if absolute then path
  else
    let cwd = Sys.getcwd () in
    let prefix = cwd ^ "/" in
    let n = String.length path and m = String.length prefix in
    if n > m && String.sub path 0 m = prefix then
      String.sub path m (n - m)
    else path
