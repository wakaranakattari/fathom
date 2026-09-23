(** File preview with ANSI highlight.
    Rendering is total and best effort: missing or unreadable files
    yield a placeholder line instead of an error. Input reads are
    capped at 10000 lines. Display lines truncate to a fixed width.
    Highlight preserves original character case and inserts ANSI bold
    red codes around each occurrence. Callers gate codes on the color
    flag and terminal capability. *)

(** [highlight ~query line] wraps case-insensitive occurrences of
    [query] in [line] with ANSI codes. An empty query returns [line]
    unchanged. A query longer than the line returns [line] unchanged.
    Complexity is O(n*m) in line and query lengths.
    @return line with embedded ANSI codes. *)
val highlight : query:string -> string -> string

(** [print_preview ~path ~query ~context ~max_lines ~color ~line_numbers]
    prints a window of [path] around the first match of [query].
    Focus is the first matching line number, or line 1 when the query
    is empty or absent. The window starts [context] lines before focus
    and spans at most [max_lines] lines. Line numbers print in a fixed
    width field when [line_numbers] holds.
    @param color enables ANSI highlight codes.
    @param line_numbers prefixes each line with its number. *)
val print_preview :
  path:string ->
  query:string ->
  context:int ->
  max_lines:int ->
  color:bool ->
  line_numbers:bool ->
  unit

(** [first_match_line ~query ~path] locates the first case-insensitive
    occurrence of [query] in [path]. At most 10000 lines are read.
    @return 1-based line number, or None when absent, empty, or
      unreadable. *)
val first_match_line : query:string -> path:string -> int option
