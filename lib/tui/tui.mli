(** Live terminal interface with plain fallback.
    The live view requires TTY stdin and stdout with a non-dumb TERM.
    Raw mode disables echo and canonical processing for the session
    duration. Terminal attributes restore on every exit path through a
    finalizer, including quit, selection, and input errors. Ranking
    recomputes per keystroke over the cached file list with history
    and repository boosts. The fallback prompt serves pipes and
    non-TTY contexts with numbered selection. *)

(** User action bound to a confirmed path. [Open] edits the path.
    [Copy] sends the path to the clipboard. [Exec cmd] runs [cmd]
    with the path appended. *)
type act =
  | Open
  | Copy
  | Exec of string

(** [is_usable ()] tests live view preconditions.
    @return true for TTY stdin and stdout with usable TERM. *)
val is_usable : unit -> bool

(** [run ~files ~initial ~limit ~preview_lines ~context ~color
    ~line_numbers ~hist ~gst ~exec] starts the live loop over cached
    [files]. Typing updates the query and resets selection to the top.
    Arrow keys and Ctrl-P with Ctrl-N move selection. Enter confirms
    the selection, Esc and Ctrl-C quit, Ctrl-Y copies the current path,
    Ctrl-U clears the query. The preview pane tracks selection with
    match focus and context window. An empty result set admits no
    selection. This function performs no history writes and launches
    no processes. Callers own post-selection effects.
    @param files cached absolute file list.
    @param initial seed query.
    @param limit maximum retained results per keystroke.
    @param preview_lines preview window height.
    @param context lines around the focus line.
    @param color enables ANSI output subject to environment gates.
    @param line_numbers prefixes preview lines with numbers.
    @param hist history table for boosts.
    @param gst repository status for boosts.
    @param exec exec template bound to Enter when present.
    @return selected path with action, or None on quit. *)
val run :
  files:string list ->
  initial:string ->
  limit:int ->
  preview_lines:int ->
  context:int ->
  color:bool ->
  line_numbers:bool ->
  hist:History.t ->
  gst:Git.status ->
  exec:string option ->
  (string * act) option

(** [prompt ~ranked ~exec] numbers pre-ranked results for non-TTY use.
    At most 20 entries print with scores. Input selects by index,
    [y] copies the top result, empty input quits. Malformed input
    quits silently with no selection.
    @param ranked results in display order.
    @param exec exec template bound to selection when present.
    @return selected path with action, or None on quit. *)
val prompt :
  ranked:Matcher.ranked list ->
  exec:string option ->
  (string * act) option
