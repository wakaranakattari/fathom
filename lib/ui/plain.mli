(** Plain text output for non-interactive use.
    This module performs output only. Ranking and selection reside
    elsewhere. Plain form targets pipes and scripts with line oriented
    records. JSON form targets programmatic consumers with escaped
    strings per specification. Color gates on the flag, [NO_COLOR],
    and TTY state. *)

(** [print_list paths] writes each path on its own line to stdout. *)
val print_list : string list -> unit

(** [print_ranked ranked] writes indexed results to stdout.
    Each line has the form [index] TAB [score] TAB [path]. Scores
    print with two decimals. Order of [ranked] is preserved.
    @param ranked results in display order. *)
val print_ranked : Matcher.ranked list -> unit

(** [print_ranked_json ranked] writes results as a JSON array.
    Each element holds [index], [score], and [path] fields. Strings
    escape quotes, backslashes, and control characters. An empty list
    prints as an empty array.
    @param ranked results in display order. *)
val print_ranked_json : Matcher.ranked list -> unit

(** [print_line_matches matches ~query ~absolute ~color] writes content
    matches in [path:line:col:text] form with 1-based line numbers and
    zero-based byte columns. Paths convert through [Scan.to_display].
    Query occurrences highlight with ANSI codes when [color] holds and
    [NO_COLOR] is absent.
    @param query highlight needle, empty disables highlight.
    @param absolute preserve full paths when true. *)
val print_line_matches :
  Search.line_match list ->
  query:string ->
  absolute:bool ->
  color:bool ->
  unit
