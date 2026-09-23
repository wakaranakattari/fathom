(** Deterministic directory traversal with ignore semantics.
    This module enumerates regular files under given roots. Traversal
    order is sorted at every level, hence output is stable across runs
    on identical trees. Symbolic links to directories are never
    followed, which excludes symlink cycles by construction. Ignore
    files extend patterns hierarchically from each visited directory.
    All returned paths are absolute and normalized. *)

(** [walk roots] enumerates files under [roots] with default options.
    Hidden entries are skipped. Ignore files are respected. Pruned
    directory names are [.git], [_build], [node_modules], [.hg],
    [_opam], and [.lsp].
    @param roots directories to traverse. Missing roots contribute
      no entries and raise no errors.
    @return sorted unique list of absolute file paths. *)
val walk : string list -> string list

(** [walk_ex ~hidden ~no_ignore roots] enumerates files with explicit
    options. When [hidden] holds, dotfiles are included while pruned
    directory names remain excluded. When [no_ignore] holds, ignore
    files are skipped entirely. Multiple roots are traversed in
    parallel domains and merged into a single sorted set.
    Complexity is linear in the number of visited entries plus
    sorting cost of the result.
    @param hidden include hidden entries.
    @param no_ignore skip ignore files.
    @param roots directories to traverse.
    @return sorted unique list of absolute file paths. *)
val walk_ex : hidden:bool -> no_ignore:bool -> string list -> string list

(** [to_display ~absolute path] converts [path] to output form.
    Conversion is a pure string operation confined to output edges.
    Ranking and storage operate on absolute paths exclusively.
    When [absolute] holds, [path] is returned unchanged. Otherwise the
    current directory prefix is stripped when present, which yields
    paths relative to the invocation directory.
    @param absolute preserve full paths.
    @return display path. *)
val to_display : absolute:bool -> string -> string
