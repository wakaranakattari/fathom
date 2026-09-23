(** Suite for Preview rendering invariants.
    Assertions cover ANSI code insertion around matches, text
    preservation, empty query identity, and first match line numbers.
    Temporary files are removed after the run. Stdlib only. Runs under
    [dune test]. *)

(* Asserts [cond]. Prints label on failure and exits non-zero. *)
let check label cond =
  if not cond then begin
    Printf.eprintf "FAIL: %s\n%!" label;
    exit 1
  end

(* Returns true when [sub] occurs in [s]. *)
let contains s sub =
  let n = String.length s and m = String.length sub in
  if m = 0 || m > n then false
  else
    let rec loop i =
      if i + m > n then false
      else if String.sub s i m = sub then true
      else loop (i + 1)
    in
    loop 0

let () =
  (* Highlight inserts codes around matches. *)
  let out = Preview.highlight ~query:"main" "bin/main.ml" in
  check "highlight inserts code" (contains out "\027[");
  check "highlight keeps text" (contains out "main");

  (* Empty query returns input unchanged. *)
  check "empty unchanged" (Preview.highlight ~query:"" "abc" = "abc");

  (* First match line finds 1-based index. *)
  let path = Filename.temp_file "fathom_prev" ".txt" in
  let oc = open_out path in
  output_string oc "alpha\nbeta match\nGamma\n";
  close_out oc;
  (match Preview.first_match_line ~query:"match" ~path with
  | Some 2 -> ()
  | _ -> check "line two" false);
  check "missing is none" (Preview.first_match_line ~query:"zzz" ~path = None);
  Sys.remove path;
  print_endline "OK"
