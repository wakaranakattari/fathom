(** Suite for Search content invariants.
    Assertions cover binary detection, case-insensitive containment,
    line number order with columns, and the empty query contract.
    Temporary files are removed after the run. Stdlib only. Runs under
    [dune test]. *)

(* Asserts [cond]. Prints label on failure and exits non-zero. *)
let check label cond =
  if not cond then begin
    Printf.eprintf "FAIL: %s\n%!" label;
    exit 1
  end

(* Writes [content] to a temp file. Returns path. *)
let temp_file content =
  let path = Filename.temp_file "fathom_test" ".txt" in
  let oc = open_out path in
  output_string oc content;
  close_out oc;
  path

let () =
  (* Binary detection rejects NUL prefix. *)
  let bin = Filename.temp_file "fathom_bin" ".bin" in
  let oc = open_out_bin bin in
  output_string oc "abc\000def";
  close_out oc;
  check "binary detected" (Search.file_is_binary bin);
  Sys.remove bin;

  (* Text file passes binary check. *)
  let txt = temp_file "hello\nworld\n" in
  check "text not binary" (not (Search.file_is_binary txt));

  (* Contains query is case-insensitive. *)
  check "contains lower" (Search.contains_query ~query:"hello" ~path:txt);
  check "contains upper" (Search.contains_query ~query:"HELLO" ~path:txt);
  check "missing yields false" (not (Search.contains_query ~query:"zzz" ~path:txt));

  (* Search returns line numbers in order. *)
  let multi = temp_file "first\nsecond match here\nthird\nfourth match\n" in
  let matches = Search.search ~query:"match" ~paths:[ multi ] ~limit:10 in
  check "two matches" (List.length matches = 2);
  (match matches with
  | [ a; b ] ->
    check "first line no" (a.Search.line_no = 2);
    check "second line no" (b.Search.line_no = 4);
    check "col non-negative" (a.Search.col >= 0)
  | _ -> check "shape" false);

  (* Empty query yields no matches. *)
  check "empty query none" (Search.search ~query:"" ~paths:[ multi ] ~limit:10 = []);

  Sys.remove txt;
  Sys.remove multi;
  print_endline "OK"
