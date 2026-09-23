(** Live terminal interface with plain fallback.
    Raw mode disables echo and canonical processing for the session.
    Signal characters are disabled so that interrupt keys restore the
    terminal through the finalizer instead of terminating the process.
    Selection state is an index into the ranked list with bounds
    clamped after every ranking pass. *)

type act =
  | Open
  | Copy
  | Exec of string

(* ANSI controls. *)
let clear_screen = "\027[2J\027[H"
let reset_attr = "\027[0m"
let reverse_attr = "\027[7m"

(** Step outcome of one input event.
    [Quit] ends the session with no selection. [Redraw] refreshes the
    screen and continues. [Done] confirms a path with its action. *)
type step =
  | Quit
  | Redraw
  | Done of (string * act)

(** Tests effective color state.
    The flag conjoins with environment gates: [NO_COLOR] presence and
    dumb or non-TTY output disable color.
    @return true when output must stay plain. *)
let color_disabled color =
  if not color then true
  else
    match Sys.getenv_opt "NO_COLOR" with
    | Some _ -> true
    | None ->
      (match Sys.getenv_opt "TERM" with
      | Some term when term = "dumb" -> true
      | _ -> not (Unix.isatty Unix.stdout))

let is_usable () =
  Unix.isatty Unix.stdin && Unix.isatty Unix.stdout
  && (match Sys.getenv_opt "TERM" with
    | Some "dumb" -> false
    | _ -> true)

(** Reads terminal dimensions through stty on the control terminal.
    Unparseable or failed probes yield a 24 by 80 fallback.
    @return rows and columns with lower bounds applied. *)
let term_size () =
  try
    let ic = Unix.open_process_in "stty size < /dev/tty 2>/dev/null" in
    let line =
      try input_line ic with End_of_file -> ""
    in
    let _ = Unix.close_process_in ic in
    (match String.split_on_char ' ' (String.trim line) with
    | [ r; c ] ->
      let rows = (try int_of_string r with Failure _ -> 24) in
      let cols = (try int_of_string c with Failure _ -> 80) in
      (max 10 rows, max 40 cols)
    | _ -> (24, 80))
  with Sys_error _ | Unix.Unix_error _ -> (24, 80)

(** Ranks cached [files] for [query] with boost composition.
    Empty queries list scanned files in order with boosts applied.
    Indices are dense from 1 after sorting.
    @return ranked list. *)
let rank_files ~files ~query ~limit ~hist ~gst =
  let base =
    if query = "" then
      List.filteri (fun i _ -> i < limit) files
      |> List.mapi (fun i p -> { Matcher.index = i + 1; path = p; score = 0.0 })
    else Matcher.rank ~query ~limit files
  in
  let boosted =
    List.map (fun (r : Matcher.ranked) ->
      let b = History.boost hist r.Matcher.path +. Git.boost gst r.Matcher.path in
      { r with Matcher.score = r.Matcher.score +. b }
    ) base
  in
  let sorted =
    List.sort (fun (a : Matcher.ranked) (b : Matcher.ranked) ->
      let c = compare b.Matcher.score a.Matcher.score in
      if c <> 0 then c else String.compare a.Matcher.path b.Matcher.path
    ) boosted
  in
  List.mapi (fun i (r : Matcher.ranked) -> { r with Matcher.index = i + 1 }) sorted

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

(** Truncates [s] to [w] columns with ellipsis marker.
    @return truncated string. *)
let truncate_cols s w =
  if String.length s <= w then s
  else if w > 3 then String.sub s 0 (w - 3) ^ "..."
  else String.sub s 0 w

(** Renders the full screen into a single buffer write.
    Layout is a query line, a bounded result window, a preview window
    for the selected entry, and a key hint footer. The selected row
    renders in reverse video when color applies. [sel] is the selected
    index within [ranked]. *)
let draw ~query ~ranked ~sel ~preview_lines ~context ~color ~line_numbers ~msg =
  let rows, cols = term_size () in
  let no_color = color_disabled color in
  let buf = Buffer.create 4096 in
  Buffer.add_string buf clear_screen;
  Buffer.add_string buf ("> " ^ query ^ "\n");
  let list_rows = min 12 (max 5 (rows / 3)) in
  let shown_total = min (List.length ranked) list_rows in
  let rec take n acc = function
    | [] -> List.rev acc
    | x :: xs -> if n <= 0 then List.rev acc else take (n - 1) (x :: acc) xs
  in
  let visible = take shown_total [] ranked in
  List.iter (fun (r : Matcher.ranked) ->
    let marker = if r.Matcher.index = sel then ">" else " " in
    let disp = truncate_cols r.Matcher.path (cols - 12) in
    if r.Matcher.index = sel && not no_color then begin
      Buffer.add_string buf reverse_attr;
      Buffer.add_string buf (Printf.sprintf "%s %3d %s\n" marker r.Matcher.index disp);
      Buffer.add_string buf reset_attr
    end
    else Buffer.add_string buf (Printf.sprintf "%s %3d %s\n" marker r.Matcher.index disp)
  ) visible;
  if List.length ranked > shown_total then
    Buffer.add_string buf (Printf.sprintf "... and %d more\n" (List.length ranked - shown_total));
  (* Preview pane for the selected entry. *)
  (match List.find_opt (fun (r : Matcher.ranked) -> r.Matcher.index = sel) ranked with
  | None -> Buffer.add_string buf "(no selection)\n"
  | Some r ->
    let lines = read_lines r.Matcher.path 500 in
    let total = List.length lines in
    if total = 0 then
      Buffer.add_string buf ("(empty: " ^ r.Matcher.path ^ ")\n")
    else begin
      let focus =
        match Preview.first_match_line ~query ~path:r.Matcher.path with
        | Some n -> n
        | None -> 1
      in
      let start = max 1 (focus - context) in
      let stop = min total (start + preview_lines - 1) in
      Buffer.add_string buf (Printf.sprintf "--- %s [%d/%d] ---\n" (truncate_cols r.Matcher.path (cols - 20)) focus total);
      List.iteri (fun i line ->
        let no = i + 1 in
        if no >= start && no <= stop then begin
          let shown = truncate_cols line (cols - 8) in
          let rendered =
            if (not no_color) && query <> "" then Preview.highlight ~query shown
            else shown
          in
          if line_numbers then Buffer.add_string buf (Printf.sprintf "%4d: %s\n" no rendered)
          else Buffer.add_string buf (rendered ^ "\n")
        end
      ) lines
    end);
  Buffer.add_string buf "Enter open | Esc quit | Ctrl-Y copy | Up/Down move\n";
  if msg <> "" then Buffer.add_string buf (msg ^ "\n");
  output_string stdout (Buffer.contents buf);
  flush stdout

(** Reads one byte from stdin through the raw descriptor.
    @return character code, or -1 when no byte is available. *)
let read_byte () =
  try
    let buf = Bytes.create 1 in
    let n = Unix.read Unix.stdin buf 0 1 in
    if n = 0 then -1 else Char.code (Bytes.get buf 0)
  with Unix.Unix_error _ -> -1

(** Tests input readiness within [timeout] seconds.
    Escape sequence parsing uses a short timeout to distinguish a lone
    escape key from sequence prefixes.
    @return true when stdin is readable. *)
let input_waiting timeout =
  try
    let (ready, _, _) = Unix.select [ Unix.stdin ] [] [] timeout in
    ready <> []
  with Unix.Unix_error _ -> false

(** Reads the remainder of an escape sequence after ESC.
    Recognized sequences are Up and Down arrows. Timeouts and unknown
    sequences resolve to a lone escape.
    @return [`Up], [`Down], or [`Esc]. *)
let read_escape () =
  if not (input_waiting 0.05) then `Esc
  else
    let b1 = read_byte () in
    if b1 <> 91 then `Esc
    else if not (input_waiting 0.05) then `Esc
    else
      let b2 = read_byte () in
      if b2 = 65 then `Up
      else if b2 = 66 then `Down
      else `Esc

let run ~files ~initial ~limit ~preview_lines ~context ~color ~line_numbers ~hist ~gst ~exec =
  let orig =
    try Some (Unix.tcgetattr Unix.stdin) with Unix.Unix_error _ -> None
  in
  let restore () =
    match orig with
    | Some t -> (try Unix.tcsetattr Unix.stdin Unix.TCSADRAIN t with Unix.Unix_error _ -> ())
    | None -> ()
  in
  Fun.protect ~finally:restore (fun () ->
    (* Raw mode engages for the session. Echo and canonical processing
        are disabled. Signal characters are disabled so interrupt keys
        resolve to quit steps with terminal restoration. *)
    (try
      let term = Unix.tcgetattr Unix.stdin in
      let raw = { term with
        Unix.c_icanon = false;
        Unix.c_echo = false;
        Unix.c_isig = false;
        Unix.c_ixon = false;
        Unix.c_icrnl = false;
        Unix.c_vmin = 1;
        Unix.c_vtime = 0;
      } in
      Unix.tcsetattr Unix.stdin Unix.TCSADRAIN raw
    with Unix.Unix_error _ -> ());
    let query = Buffer.create 64 in
    Buffer.add_string query initial;
    let sel = ref 1 in
    let msg = ref "" in
    let ranked = ref (rank_files ~files ~query:(Buffer.contents query) ~limit ~hist ~gst) in
    draw ~query:(Buffer.contents query) ~ranked:!ranked ~sel:!sel
      ~preview_lines ~context ~color ~line_numbers ~msg:!msg;
    let loop () : step =
      let c = read_byte () in
      if c = -1 then Quit
      else if c = 27 then begin
        match read_escape () with
        | `Esc -> Quit
        | `Up -> sel := max 1 (!sel - 1); Redraw
        | `Down -> sel := !sel + 1; Redraw
      end
      else if c = 3 then Quit
      else if c = 13 || c = 10 then begin
        match List.find_opt (fun (r : Matcher.ranked) -> r.Matcher.index = !sel) !ranked with
        | None -> msg := "No selection."; Redraw
        | Some r ->
          (match exec with
          | Some cmd -> Done (r.Matcher.path, Exec cmd)
          | None -> Done (r.Matcher.path, Open))
      end
      else if c = 25 then begin
        (* Control-Y copies the current selection to the clipboard.
            Unavailable tools leave a status notice in the footer. *)
        (match List.find_opt (fun (r : Matcher.ranked) -> r.Matcher.index = !sel) !ranked with
        | None -> msg := "No selection."
        | Some r ->
          if Clip.copy r.Matcher.path then msg := "Copied to clipboard."
          else msg := "Clipboard unavailable. Path printed on exit.");
        Redraw
      end
      else if c = 14 then begin sel := !sel + 1; Redraw end
      else if c = 16 then begin sel := max 1 (!sel - 1); Redraw end
      else if c = 127 || c = 8 then begin
        let len = Buffer.length query in
        if len > 0 then begin
          let s = Buffer.contents query in
          Buffer.clear query;
          Buffer.add_string query (String.sub s 0 (len - 1));
          sel := 1;
          msg := "";
        end;
        Redraw
      end
      else if c = 21 then begin
        Buffer.clear query;
        sel := 1;
        msg := "";
        Redraw
      end
      else if c >= 32 && c <= 126 then begin
        Buffer.add_char query (Char.chr c);
        sel := 1;
        msg := "";
        Redraw
      end
      else Redraw
    in
    let rec drive () =
      ranked := rank_files ~files ~query:(Buffer.contents query) ~limit ~hist ~gst;
      let total = List.length !ranked in
      if total = 0 then sel := 1
      else if !sel > total then sel := total
      else if !sel < 1 then sel := 1;
      draw ~query:(Buffer.contents query) ~ranked:!ranked ~sel:!sel
        ~preview_lines ~context ~color ~line_numbers ~msg:!msg;
      match loop () with
      | Quit -> None
      | Done v -> Some v
      | Redraw ->
        ranked := rank_files ~files ~query:(Buffer.contents query) ~limit ~hist ~gst;
        let total = List.length !ranked in
        if total = 0 then sel := 1
        else if !sel > total then sel := total;
        draw ~query:(Buffer.contents query) ~ranked:!ranked ~sel:!sel
          ~preview_lines ~context ~color ~line_numbers ~msg:!msg;
        drive ()
    in
    (* The driver performs an initial ranking pass before input so
        selection bounds hold on the first frame. *)
    drive ()
  )
(* Plain numbered selection for non-TTY contexts.
   Results print with scores in stable order. Input grammar is an
   index, [y] for the top result copy, or empty input for quit. *)
let prompt ~ranked ~exec =
  let total = List.length ranked in
  if total = 0 then None
  else begin
    let rec take n acc = function
      | [] -> List.rev acc
      | x :: xs -> if n <= 0 then List.rev acc else take (n - 1) (x :: acc) xs
    in
    let shown = take 20 [] ranked in
    List.iter (fun (r : Matcher.ranked) ->
      Printf.printf "%d\t%.2f\t%s\n%!" r.Matcher.index r.Matcher.score r.Matcher.path
    ) shown;
    if total > 20 then Printf.printf "... and %d more\n%!" (total - 20);
    Printf.printf "Select 1-%d, y to copy, empty to quit: %!" total;
    try
      let line = String.trim (read_line ()) in
      if line = "" then None
      else if line = "y" || line = "Y" then
        (match ranked with
        | r :: _ -> Some (r.Matcher.path, Copy)
        | [] -> None)
      else
        let idx = int_of_string line in
        (match List.find_opt (fun (r : Matcher.ranked) -> r.Matcher.index = idx) ranked with
        | None -> None
        | Some r ->
          (match exec with
          | Some cmd -> Some (r.Matcher.path, Exec cmd)
          | None -> Some (r.Matcher.path, Open)))
    with End_of_file -> None
    | Failure _ -> None
    end
