(** Plain text output with stable record shapes.
    Plain form targets pipes with line oriented records. JSON form
    targets program consumers with escaped strings. *)

let print_list paths =
  List.iter (fun p -> print_endline p) paths

let print_ranked (ranked : Matcher.ranked list) =
  List.iter (fun (r : Matcher.ranked) ->
    Printf.printf "%d\t%.2f\t%s\n" r.index r.score r.path
  ) ranked

(** Escapes [s] for JSON string content.
    Quotes, backslashes, and control characters take escape forms.
    Remaining characters pass through, including non-ASCII bytes.
    @return escaped string without surrounding quotes. *)
let json_escape s =
  let buf = Buffer.create (String.length s + 2) in
  String.iter (fun c ->
    match c with
    | '"' -> Buffer.add_string buf "\\\""
    | '\\' -> Buffer.add_string buf "\\\\"
    | '\n' -> Buffer.add_string buf "\\n"
    | '\r' -> Buffer.add_string buf "\\r"
    | '\t' -> Buffer.add_string buf "\\t"
    | c when Char.code c < 32 -> Buffer.add_string buf (Printf.sprintf "\\u%04x" (Char.code c))
    | c -> Buffer.add_char buf c
  ) s;
  Buffer.contents buf

let print_ranked_json (ranked : Matcher.ranked list) =
  print_string "[\n";
  let rec loop = function
    | [] -> ()
    | [ (r : Matcher.ranked) ] ->
      Printf.printf "  {\"index\": %d, \"score\": %.2f, \"path\": \"%s\"}\n"
        r.index r.score (json_escape r.path)
    | (r : Matcher.ranked) :: rest ->
      Printf.printf "  {\"index\": %d, \"score\": %.2f, \"path\": \"%s\"},\n"
        r.index r.score (json_escape r.path);
      loop rest
  in
  loop ranked;
  print_string "]\n";
  flush stdout

let print_line_matches matches ~query ~absolute ~color =
  let use_color =
    color
    && (match Sys.getenv_opt "NO_COLOR" with Some _ -> false | None -> true)
  in
  List.iter (fun (m : Search.line_match) ->
    let disp = Scan.to_display ~absolute m.Search.path in
    let text =
      if use_color && query <> "" then Preview.highlight ~query m.Search.line
      else m.Search.line
    in
    Printf.printf "%s:%d:%d:%s\n%!" disp m.Search.line_no m.Search.col text
  ) matches
