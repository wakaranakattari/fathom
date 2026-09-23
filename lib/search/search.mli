(** Content search with line granularity.
    Matching is case-insensitive over ASCII. Binary files are detected
    by NUL prefix inspection and excluded. Files above the size bound
    are excluded without content reads. All scans are sequential and
    bounded, hence latency is proportional to scanned input up to the
    match limit. *)

(** A single matching line. [path] is the scanned file. [line_no] is
    the 1-based line number. [col] is the zero-based byte offset of
    the match within [line]. [line] holds the truncated line text. *)
type line_match = {
  path : string;
  line_no : int;
  col : int;
  line : string;
}

(** [file_is_binary path] inspects the file prefix for NUL bytes.
    At most the first 8192 bytes are read. Unreadable files report
    true, which excludes them from content results.
    @return true for binary or unreadable files. *)
val file_is_binary : string -> bool

(** [contains_query ~query ~path] tests file content for [query].
    Files above 1048576 bytes and binary files yield false without
    full scans. An empty query yields false.
    @return true when a case-insensitive match exists. *)
val contains_query : query:string -> path:string -> bool

(** [search ~query ~paths ~limit] scans [paths] in order for [query].
    Matches accumulate in path and line order up to [limit]. Lines
    truncate to 500 bytes with an ellipsis marker. An empty query or
    a non-positive limit yields an empty list.
    Complexity is linear in scanned bytes up to the match limit.
    @param limit maximum matches to collect.
    @return matches in scan order. *)
val search : query:string -> paths:string list -> limit:int -> line_match list
