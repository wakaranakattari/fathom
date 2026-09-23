(** Clipboard delivery through external system tools.
    Tool order is fixed: [wl-copy], [xclip], [xsel], [pbcopy],
    [clip.exe]. Presence tests use PATH lookup. Delivery pipes text to
    tool stdin and interprets the exit code. *)

(** Tests tool presence on PATH through shell lookup.
    @return true on zero lookup exit. *)
let tool_exists tool =
  try
    let cmd = Printf.sprintf "command -v %s >/dev/null 2>&1" tool in
    Sys.command cmd = 0
  with Sys_error _ -> false

(** Pipes [text] to stdin of [cmd].
    @return true on zero tool exit, false on any failure. *)
let pipe_to cmd text =
  try
    let oc = Unix.open_process_out cmd in
    output_string oc text;
    close_out oc;
    let status = Unix.close_process_out oc in
    status = Unix.WEXITED 0
  with Sys_error _ | Unix.Unix_error _ -> false

let copy text =
  if text = "" then false
  else if tool_exists "wl-copy" then pipe_to "wl-copy" text
  else if tool_exists "xclip" then pipe_to "xclip -selection clipboard" text
  else if tool_exists "xsel" then pipe_to "xsel --clipboard --input" text
  else if tool_exists "pbcopy" then pipe_to "pbcopy" text
  else if tool_exists "clip.exe" then pipe_to "clip.exe" text
  else false

let available () =
  tool_exists "wl-copy"
  || tool_exists "xclip"
  || tool_exists "xsel"
  || tool_exists "pbcopy"
  || tool_exists "clip.exe"
