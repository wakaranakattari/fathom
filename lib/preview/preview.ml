(** Preview rendering with ANSI highlight.
    Highlight preserves original case and wraps each occurrence in
    bold red codes. Reads cap at a fixed line count. Display lines
    truncate to a fixed width estimate. *)

(** ANSI open and close codes for match runs. *)
let start_hl = "\027[1;31m"
let end_hl = "\027[0m"

(** Case folding over ASCII letters.
    Non-ASCII bytes pass through unchanged.
    @return folded string. *)
let lower_ascii s =
  String.map (fun c ->
    if c >= 'A' && c <= 'Z' then Char.chr (Char.code c + 32) else c
  ) s

(** Wraps each occurrence of [query] in [line] with ANSI codes.
    Original case is preserved through parallel folded comparison.
    Complexity is O(n*m) in line and query lengths.
    @return line with embedded codes. *)
let highlight ~query line =
  if query = "" then line
  else
    let q = lower_ascii query in
    let t = lower_ascii line in
    let n = String.length line and m = String.length q in
    if m > n then line
    else
      let buf = Buffer.create (n + 16) in
      let rec loop i =
        if i + m > n then begin
          Buffer.add_substring buf line i (n - i)
        end
        else if String.sub t i m = q then begin
          Buffer.add_string buf start_hl;
          Buffer.add_substring buf line i m;
          Buffer.add_string buf end_hl;
          loop (i + m)
        end
        else begin
          Buffer.add_char buf line.[i];
          loop (i + 1)
        end
      in
      loop 0;
      Buffer.contents buf

(** Truncates a display line to [width] columns.
    Longer lines keep a prefix with an ellipsis marker.
    @return truncated line. *)
let truncate_display line width =
  if String.length line <= width then line
  else String.sub line 0 width ^ "..."

(** Reads up to [cap] lines from [path] in order.
    @return line list, empty on any read failure. *)
let read_lines path cap =
  try
    let ic = open_in_bin path in
    let rec loop n acc =
      if n >= cap then (close_in ic; List.rev acc)
      else
        (try
          let line = input_line ic in
          loop (n + 1) (line :: acc)
        with End_of_file -> close_in ic; List.rev acc)
    in
    loop 0 []
  with Sys_error _ -> []

let first_match_line ~query ~path =
  if query = "" then None
  else
    let lines = read_lines path 10000 in
    let q = lower_ascii query in
    let rec loop idx = function
      | [] -> None
      | line :: rest ->
        let t = lower_ascii line in
        let n = String.length t and m = String.length q in
        let rec find i =
          if m = 0 then false
          else if i + m > n then false
          else if String.sub t i m = q then true
          else find (i + 1)
        in
        if m <= n && find 0 then Some idx else loop (idx + 1) rest
    in
    loop 1 lines

let print_preview ~path ~query ~context ~max_lines ~color ~line_numbers =
  let lines = read_lines path 10000 in
  let total = List.length lines in
  if total = 0 then Printf.printf "(empty or unreadable: %s)\n%!" path
  else begin
    let focus =
      match first_match_line ~query ~path with
      | Some n -> n
      | None -> 1
    in
    let start = max 1 (focus - context) in
    let stop = min total (start + max_lines - 1) in
    let width = 120 in
    Printf.printf "--- %s (line %d of %d) ---\n%!" path focus total;
    List.iteri (fun i line ->
      let no = i + 1 in
      if no >= start && no <= stop then begin
        let shown = truncate_display line width in
        let rendered =
          if color && query <> "" then highlight ~query shown else shown
        in
        if line_numbers then Printf.printf "%4d: %s\n%!" no rendered
        else Printf.printf "%s\n%!" rendered
      end
    ) lines
  end
