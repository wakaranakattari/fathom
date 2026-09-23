(** File configuration with command line overrides.
    Format is line based [key = value]. Blank lines and [#] comments
    are skipped. Lines without exactly one [=] separator are ignored.
    Unknown keys are ignored. Invalid values preserve prior settings,
    hence malformed files degrade to defaults deterministically. *)

(** Effective options after config and CLI merge. Command line flags
    override file values field by field. *)
type t = {
  limit : int;
  preview_lines : int;
  context : int;
  color : bool;
  hidden : bool;
  absolute : bool;
  line_numbers : bool;
  no_ignore : bool;
  no_history : bool;
}

(** Default options applied when no config file exists or when values
    are invalid. Limits are [limit] 50, [preview_lines] 12, [context]
    3, with color and line numbers enabled and remaining flags off. *)
val default : t

(** [load path] reads options from [path] over defaults.
    Missing files yield [default]. Each valid line updates one field
    with range validation: [limit] in 1 to 1000, [preview_lines] in 1
    to 100, [context] in 0 to 20. Booleans accept [true], [false],
    [1], [0], [yes], [no], [on], [off] case-insensitively.
    @return effective options. *)
val load : string -> t

(** [default_path ()] resolves the config location.
    Precedence is [FATHOM_CONFIG] when set and non-empty, then
    [XDG_CONFIG_HOME] with fallback to [$HOME/.config], resolved to
    the [fathom/config] file beneath the base directory.
    @return config file path. *)
val default_path : unit -> string
