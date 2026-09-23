(** Line based file configuration.
    Each valid line holds [key = value]. Comment lines open with [#].
    Unknown keys are ignored. Invalid values preserve prior settings,
    hence any file degrades deterministically toward defaults. *)

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

let default = {
  limit = 50;
  preview_lines = 12;
  context = 3;
  color = true;
  hidden = false;
  absolute = false;
  line_numbers = true;
  no_ignore = false;
  no_history = false;
}

(** Parses boolean tokens case-insensitively.
    Accepted truths are [true], [1], [yes], [on]. Accepted falsities
    are [false], [0], [no], [off].
    @return boolean value, or None for unknown input. *)
let parse_bool s =
  match String.lowercase_ascii (String.trim s) with
  | "true" | "1" | "yes" | "on" -> Some true
  | "false" | "0" | "no" | "off" -> Some false
  | _ -> None

(** Parses integer tokens with surrounding whitespace ignored.
    @return integer value, or None for invalid input. *)
let parse_int s =
  try Some (int_of_string (String.trim s)) with Failure _ -> None

(** Applies one key value pair to [cfg] with range validation.
    Integer fields validate documented bounds. Unknown keys pass
    through unchanged.
    @return updated configuration. *)
let apply cfg key value =
  let k = String.lowercase_ascii (String.trim key) in
  if k = "limit" then
    (match parse_int value with
    | Some n when n > 0 && n <= 1000 -> { cfg with limit = n }
    | _ -> cfg)
  else if k = "preview_lines" then
    (match parse_int value with
    | Some n when n > 0 && n <= 100 -> { cfg with preview_lines = n }
    | _ -> cfg)
  else if k = "context" then
    (match parse_int value with
    | Some n when n >= 0 && n <= 20 -> { cfg with context = n }
    | _ -> cfg)
  else if k = "color" then
    (match parse_bool value with
    | Some b -> { cfg with color = b }
    | None -> cfg)
  else if k = "hidden" then
    (match parse_bool value with
    | Some b -> { cfg with hidden = b }
    | None -> cfg)
  else if k = "absolute" then
    (match parse_bool value with
    | Some b -> { cfg with absolute = b }
    | None -> cfg)
  else if k = "line_numbers" then
    (match parse_bool value with
    | Some b -> { cfg with line_numbers = b }
    | None -> cfg)
  else if k = "no_ignore" then
    (match parse_bool value with
    | Some b -> { cfg with no_ignore = b }
    | None -> cfg)
  else if k = "no_history" then
    (match parse_bool value with
    | Some b -> { cfg with no_history = b }
    | None -> cfg)
  else cfg

let load path =
  try
    let ic = open_in path in
    let rec loop cfg =
      try
        let line = String.trim (input_line ic) in
        if line = "" then loop cfg
        else if line.[0] = '#' then loop cfg
        else
          (match String.split_on_char '=' line with
          | [ key; value ] -> loop (apply cfg key value)
          | _ -> loop cfg)
      with End_of_file ->
        close_in ic;
        cfg
    in
    loop default
  with Sys_error _ -> default

let default_path () =
  match Sys.getenv_opt "FATHOM_CONFIG" with
  | Some p when p <> "" -> p
  | _ ->
    let base =
      match Sys.getenv_opt "XDG_CONFIG_HOME" with
      | Some dir when dir <> "" -> dir
      | _ ->
        (match Sys.getenv_opt "HOME" with
        | Some home -> Filename.concat home ".config"
        | None -> ".")
    in
    Filename.concat (Filename.concat base "fathom") "config"
