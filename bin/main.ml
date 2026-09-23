(** Command line entry point.
    Responsibilities of this module are limited to argument parsing,
    configuration merge, pipeline wiring, and process exit codes.
    Search, ranking, storage, and rendering reside in library modules.
    No algorithmic logic belongs here. *)

type mode =
  | Mixed
  | Files
  | Text

let version = "0.1.0"

(** Collects process arguments after the program name.
    A token equal to "--" is a positional separator with no meaning
    of its own and is removed. Remaining tokens keep original order.
    @return argument list without the program name. *)
let option_args () =
  Array.to_list Sys.argv
  |> List.tl
  |> List.filter (fun s -> s <> "--")

(** Locates the [--config] value in pre-parsed option arguments.
    A separate pass precedes full parsing so file options establish
    defaults before command line flags override them.
    @param opt_args filtered argument list.
    @return config path when the flag is present, None otherwise. *)
let pre_scan_config opt_args =
  let rec loop = function
    | [] -> None
    | "--config" :: value :: _ -> Some value
    | _ :: rest -> loop rest
  in
  loop opt_args

(** Combines history and repository boosts with base scores.
    Results sort in decreasing order of total score with path order
    as tiebreak. Indices are reassigned from 1 after sorting.
    @return ranked list with stable dense indices. *)
let apply_boosts hist gst (ranked : Matcher.ranked list) =
  let boosted =
    List.map (fun (r : Matcher.ranked) ->
      let b = History.boost hist r.Matcher.path +. Git.boost gst r.Matcher.path in
      { r with Matcher.score = r.Matcher.score +. b }
    ) ranked
  in
  let sorted =
    List.sort (fun (a : Matcher.ranked) (b : Matcher.ranked) ->
      let c = compare b.Matcher.score a.Matcher.score in
      if c <> 0 then c else String.compare a.Matcher.path b.Matcher.path
    ) boosted
  in
  List.mapi (fun i (r : Matcher.ranked) -> { r with Matcher.index = i + 1 }) sorted

(** Converts ranked absolute paths to display form.
    Path conversion is confined to output edges. Ranking and storage
    operate on absolute paths exclusively.
    @param absolute preserves full paths when true.
    @return ranked list with display paths. *)
let display_ranked ~absolute (ranked : Matcher.ranked list) =
  List.map (fun (r : Matcher.ranked) ->
    { r with Matcher.path = Scan.to_display ~absolute r.Matcher.path }
  ) ranked

(** Opens [path] in the configured editor.
    The editor is taken from [EDITOR] with fallback to [vi].
    The path is shell-quoted before invocation.
    @return process exit code, 1 on abnormal termination. *)
let open_in_editor path =
  let editor =
    match Sys.getenv_opt "EDITOR" with
    | Some e when String.trim e <> "" -> String.trim e
    | _ -> "vi"
  in
  (match Unix.system (editor ^ " " ^ Filename.quote path) with
  | Unix.WEXITED n -> n
  | Unix.WSIGNALED _ | Unix.WSTOPPED _ -> 1)

(** Runs [cmd] with [path] appended as a quoted argument.
    @return process exit code, 1 on abnormal termination. *)
let run_exec cmd path =
  (match Unix.system (cmd ^ " " ^ Filename.quote path) with
  | Unix.WEXITED n -> n
  | Unix.WSIGNALED _ | Unix.WSTOPPED _ -> 1)

(** Handles a confirmed selection.
    History is recorded unless disabled. The process terminates with
    the exit code of the resulting action.
    @param act action chosen in the interface. *)
let handle_selection ~hist ~hist_path ~no_history path (act : Tui.act) =
  if not no_history then begin
    let updated = History.record hist path in
    History.save updated hist_path
  end;
  (match act with
  | Tui.Open -> exit (open_in_editor path)
  | Tui.Copy ->
    if Clip.copy path then (print_endline path; exit 0)
    else (print_endline path; exit 0)
  | Tui.Exec cmd -> exit (run_exec cmd path))

let () =
  (* Configuration establishes defaults. Command line flags override
      file values. Parsing consumes filtered option arguments. *)
  let opt_args = option_args () in
  let cfg_path =
    match pre_scan_config opt_args with
    | Some p -> p
    | None -> Config.default_path ()
  in
  let cfg = Config.load cfg_path in
  let query = ref "" in
  let extra_roots = ref [] in
  let print_flag = ref false in
  let json_flag = ref false in
  let files_only = ref false in
  let text_only = ref false in
  let mixed_flag = ref false in
  let exec_template = ref None in
  let copy_flag = ref false in
  let preview_flag = ref false in
  let limit = ref cfg.Config.limit in
  let preview_lines = ref cfg.Config.preview_lines in
  let context = ref cfg.Config.context in
  let color = ref cfg.Config.color in
  let hidden = ref cfg.Config.hidden in
  let absolute = ref cfg.Config.absolute in
  let line_numbers = ref cfg.Config.line_numbers in
  let no_ignore = ref cfg.Config.no_ignore in
  let no_history = ref cfg.Config.no_history in
  let roots = ref [] in
  let show_version = ref false in
  let config_path = ref cfg_path in
  let speclist = [
    ("--print", Arg.Set print_flag, "Print results and exit.");
    ("--json", Arg.Set json_flag, "Print results as JSON and exit.");
    ("--files", Arg.Set files_only, "Search file names only.");
    ("--text", Arg.Set text_only, "Search file contents only.");
    ("--mixed", Arg.Set mixed_flag, "Search names and contents (default).");
    ("--exec", Arg.String (fun s -> exec_template := Some s), "Run CMD with selected file.");
    ("--copy", Arg.Set copy_flag, "Copy selected path to clipboard.");
    ("--preview", Arg.Set preview_flag, "Show preview of top result in print mode.");
    ("--limit", Arg.Set_int limit, "Max results to show.");
    ("--root", Arg.String (fun s -> roots := s :: !roots), "Root directory to scan (repeatable).");
    ("--preview-lines", Arg.Set_int preview_lines, "Preview lines in TUI.");
    ("--context", Arg.Set_int context, "Context lines around match.");
    ("--color", Arg.Unit (fun () -> color := true), "Force color output.");
    ("--no-color", Arg.Unit (fun () -> color := false), "Disable color output.");
    ("--hidden", Arg.Unit (fun () -> hidden := true), "Include hidden files.");
    ("--no-hidden", Arg.Unit (fun () -> hidden := false), "Skip hidden files.");
    ("--absolute", Arg.Unit (fun () -> absolute := true), "Print absolute paths.");
    ("--relative", Arg.Unit (fun () -> absolute := false), "Print relative paths.");
    ("--line-numbers", Arg.Unit (fun () -> line_numbers := true), "Show line numbers in preview.");
    ("--no-line-numbers", Arg.Unit (fun () -> line_numbers := false), "Hide line numbers.");
    ("--no-ignore", Arg.Unit (fun () -> no_ignore := true), "Skip ignore files.");
    ("--no-history", Arg.Unit (fun () -> no_history := true), "Disable history read and write.");
    ("--config", Arg.Set_string config_path, "Config file path.");
    ("--version", Arg.Set show_version, "Print version and exit.");
  ] in
  let usage = "fathom [QUERY] [ROOTS...] [options]" in
  let anon s =
    if !query = "" then query := s
    else extra_roots := s :: !extra_roots
  in
  Arg.parse_argv (Array.of_list (Sys.argv.(0) :: opt_args)) speclist anon usage;
  if !show_version then begin
    Printf.printf "fathom %s\n%!" version;
    exit 0
  end;
  if !limit <= 0 then (prerr_endline "Limit must be positive."; exit 2);
  if !limit > 1000 then limit := 1000;
  let mode =
    if !files_only then Files
    else if !text_only then Text
    else Mixed
  in
  let _ = mixed_flag in
  let scan_roots =
    let from_flag = List.rev !roots in
    let from_pos = List.rev !extra_roots in
    match from_flag @ from_pos with
    | [] -> [ "." ]
    | lst -> lst
  in
  let files = Scan.walk_ex ~hidden:!hidden ~no_ignore:!no_ignore scan_roots in
  let hist_path = History.default_path () in
  let hist =
    if !no_history then History.empty
    else History.load hist_path
  in
  let gst = Git.status () in
  let q = !query in
  (* Content mode with line granularity. Print form emits line matches.
      JSON form emits ranked file paths derived from those matches. *)
  if mode = Text && (!print_flag || !json_flag) then begin
    let matches = Search.search ~query:q ~paths:files ~limit:(!limit * 10) in
    if !json_flag then begin
      let ranked_paths =
        matches
        |> List.map (fun (m : Search.line_match) -> m.Search.path)
        |> List.sort_uniq String.compare
      in
      let ranked = Matcher.rank ~query:q ~limit:!limit ranked_paths in
      let ranked = apply_boosts hist gst ranked in
      let shown = display_ranked ~absolute:!absolute ranked in
      Plain.print_ranked_json shown
    end
    else begin
      Plain.print_line_matches matches ~query:q ~absolute:!absolute ~color:!color;
      if !preview_flag then
        (match matches with
        | (m : Search.line_match) :: _ ->
          Preview.print_preview ~path:m.Search.path ~query:q ~context:!context
            ~max_lines:!preview_lines ~color:!color ~line_numbers:!line_numbers
        | [] -> ())
    end;
    exit 0
  end;
  (* Name and mixed modes share the ranking stage. Mixed mode unions
      name matches with content matches after name deduplication. *)
  let candidates =
    match mode with
    | Files -> files
    | Text ->
      List.filter (fun p -> Search.contains_query ~query:q ~path:p) files
    | Mixed ->
      if q = "" then files
      else begin
        let by_name = Matcher.rank ~query:q ~limit:(!limit * 2) files in
        let names = List.map (fun (r : Matcher.ranked) -> r.Matcher.path) by_name in
        let by_content =
          List.filter (fun p ->
            not (List.mem p names) && Search.contains_query ~query:q ~path:p
          ) files
        in
        let content_ranked = Matcher.rank ~query:q ~limit:!limit by_content in
        let content_paths = List.map (fun (r : Matcher.ranked) -> r.Matcher.path) content_ranked in
        names @ content_paths
      end
  in
  let ranked =
    match mode with
    | Files -> Matcher.rank ~query:q ~limit:!limit candidates
    | Text -> Matcher.rank ~query:q ~limit:!limit candidates
    | Mixed ->
      if q = "" then
        List.mapi (fun i p -> { Matcher.index = i + 1; path = p; score = 0.0 })
          (List.filteri (fun i _ -> i < !limit) candidates)
      else Matcher.rank ~query:q ~limit:!limit candidates
  in
  let ranked = apply_boosts hist gst ranked in
  let shown = display_ranked ~absolute:!absolute ranked in
  (* Non-interactive output stages. Each stage terminates the process. *)
  if !json_flag then begin
    Plain.print_ranked_json shown;
    exit 0
  end;
  if !print_flag then begin
    Plain.print_ranked shown;
    if !preview_flag then
      (match ranked with
      | r :: _ ->
        Preview.print_preview ~path:r.Matcher.path ~query:q ~context:!context
          ~max_lines:!preview_lines ~color:!color ~line_numbers:!line_numbers
      | [] -> ());
    (* Print mode applies copy and exec to the top result on request. *)
    (match (!copy_flag, !exec_template, ranked) with
    | (true, _, r :: _) ->
      let _ = Clip.copy r.Matcher.path in
      ()
    | (_, Some cmd, r :: _) ->
      exit (run_exec cmd r.Matcher.path)
    | _ -> ());
    exit 0
  end;
  (* Piped stdout implies print form for script composition. *)
  if not (Unix.isatty Unix.stdout) then begin
    Plain.print_ranked shown;
    exit 0
  end;
  (* Copy without selection operates on the top result. *)
  if !copy_flag && q <> "" then begin
    match ranked with
    | [] -> prerr_endline "No matches."; exit 1
    | r :: _ ->
      if not !no_history then begin
        let updated = History.record hist r.Matcher.path in
        History.save updated hist_path
      end;
      let ok = Clip.copy r.Matcher.path in
      print_endline r.Matcher.path;
      if not ok then prerr_endline "Clipboard tool not found. Path printed.";
      exit 0
  end;
  (* Exec without selection operates on the top result. *)
  (match (!exec_template, q) with
  | (Some cmd, q) when q <> "" ->
    (match ranked with
    | [] -> prerr_endline "No matches."; exit 1
    | r :: _ ->
      if not !no_history then begin
        let updated = History.record hist r.Matcher.path in
        History.save updated hist_path
      end;
      exit (run_exec cmd r.Matcher.path))
  | _ -> ());
  (* Interactive selection. The live view requires a TTY.
      Remaining contexts use the numbered fallback. *)
  let result =
    if Tui.is_usable () then
      Tui.run ~files ~initial:q ~limit:!limit ~preview_lines:!preview_lines
        ~context:!context ~color:!color ~line_numbers:!line_numbers
        ~hist ~gst ~exec:!exec_template
    else
      Tui.prompt ~ranked ~exec:!exec_template
  in
  (match result with
  | None -> exit 0
  | Some (path, act) ->
    let act =
      match (act, !copy_flag) with
      | (Tui.Open, true) -> Tui.Copy
      | _ -> act
    in
    handle_selection ~hist ~hist_path ~no_history:!no_history path act)
