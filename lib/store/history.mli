(** Access history for recency and frequency boosts.
    Storage is plain tab separated text: path, count, timestamp per
    line. Reads tolerate missing files and malformed lines. Writes are
    total and silent: parent directories are created as needed and IO
    errors are ignored, since history is auxiliary data that never
    affects correctness of results. *)

(** In-memory history table keyed by absolute path. *)
type t

(** Empty table with no entries. Boosts over [empty] are zero. *)
val empty : t

(** [load path] reads a history table from [path].
    Missing files yield [empty]. Malformed lines are skipped.
    Duplicate paths keep the last valid entry.
    @return loaded table. *)
val load : string -> t

(** [record t path] registers an access of [path] at the current time.
    Known paths increment the count and refresh the timestamp.
    Unknown paths enter with count 1. The table is updated in place
    and returned for pipeline composition.
    @return the updated table. *)
val record : t -> string -> t

(** [save t path] writes [t] to [path] in full.
    Parent directories are created as needed. Errors are ignored.
    @return unit. *)
val save : t -> string -> unit

(** [boost t path] scores prior access of [path].
    Recency decays over days from the last access with weight 8.0 at
    zero age. Frequency adds a logarithmic term in the access count,
    which bounds dominance of old frequent paths. Unknown paths score
    zero.
    @return non-negative boost. *)
val boost : t -> string -> float

(** [default_path ()] resolves the history file location.
    Precedence is [XDG_CACHE_HOME] with fallback to [$HOME/.cache],
    resolved to the [fathom/history.tsv] file beneath the base.
    @return history file path. *)
val default_path : unit -> string
