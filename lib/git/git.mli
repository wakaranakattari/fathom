(** Repository awareness for ranking boosts.
    Status derives from porcelain v1 output with capped reads, hence
    large repositories cannot stall startup. All git invocations are
    best effort: failures and non-repository directories yield empty
    status. Returned paths are absolute, resolved against the
    repository toplevel. *)

(** File status groups. Each list holds absolute paths. [modified]
    covers working tree and staged modifications. [added] covers staged
    additions. [untracked] covers unknown files. *)
type status = {
  modified : string list;
  added : string list;
  untracked : string list;
}

(** Empty status with no entries in any group. *)
val empty : status

(** [toplevel ()] resolves the repository root of the invocation
    directory through [git rev-parse].
    @return root path, or None outside a repository or on git failure. *)
val toplevel : unit -> string option

(** [status ()] parses [git status --porcelain=v1] of the invocation
    directory. Rename entries resolve to the target side. Quoted paths
    are unquoted. Output beyond the read cap is ignored.
    @return status groups with absolute paths. *)
val status : unit -> status

(** [boost st path] scores repository membership of [path].
    Modified files receive 5.0, added files 3.0, untracked files 2.0.
    Remaining paths receive 0.0.
    @return non-negative boost. *)
val boost : status -> string -> float
