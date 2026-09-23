(** Clipboard integration with tool detection.
    Tools probe in fixed order: [wl-copy], [xclip], [xsel], [pbcopy],
    [clip.exe]. Text pipes to tool stdin. Exit codes determine success.
    All operations are total and silent: missing tools and pipe errors
    report false with no output and no exceptions. *)

(** [copy text] sends [text] to the system clipboard through the first
    available tool. Empty input yields false without tool invocation.
    @return true on zero tool exit, false otherwise. *)
val copy : string -> bool

(** [available ()] reports tool presence on PATH.
    @return true when at least one clipboard tool resolves. *)
val available : unit -> bool
