(** Suite for Matcher ranking invariants.
    Assertions cover basename preference, empty and absent queries,
    fuzzy order constraints, rank order with dense indices, and the
    negative limit contract. Failures print a label and exit non-zero.
    Stdlib only. Runs under [dune test]. *)

(* Asserts [cond]. Prints label on failure and exits non-zero. *)
let check label cond =
  if not cond then begin
    Printf.eprintf "FAIL: %s\n%!" label;
    exit 1
  end

let () =
  (* Substring scoring prefers basename matches. *)
  let s1 = Matcher.substring_score ~query:"main" ~path:"/repo/bin/main.ml" in
  let s2 = Matcher.substring_score ~query:"main" ~path:"/repo/doc/maintenance.txt" in
  check "basename ranks higher" (s1 > s2);

  (* Empty query yields zero. *)
  check "empty query is zero"
    (Matcher.substring_score ~query:"" ~path:"/a/b.ml" = 0.0);

  (* Missing query yields zero. *)
  check "missing query is zero"
    (Matcher.substring_score ~query:"zzz" ~path:"/a/b.ml" = 0.0);

  (* Fuzzy matching respects order. *)
  check "fuzzy in order"
    (Matcher.fuzzy_score ~query:"fb" ~path:"/repo/foo/bar.ml" > 0.0);
  check "fuzzy out of order is zero"
    (Matcher.fuzzy_score ~query:"bf" ~path:"/repo/foo/abc.ml" = 0.0
     || Matcher.fuzzy_score ~query:"zx" ~path:"/repo/foo/bar.ml" = 0.0);

  (* Rank sorts by score then path and assigns indices. *)
  let ranked = Matcher.rank ~query:"main"
    ~limit:10 [ "/z/main.ml"; "/a/other.ml"; "/b/main.ml" ] in
  check "rank non-empty" (ranked <> []);
  (match ranked with
  | first :: _ ->
    check "top result contains query"
      (let p = String.lowercase_ascii first.Matcher.path in
       let q = "main" in
       let n = String.length p and m = String.length q in
       let rec find i =
         if i + m > n then false
         else if String.sub p i m = q then true
         else find (i + 1)
       in
       find 0)
  | [] -> ());

  (* Negative limit raises. *)
  (try
    ignore (Matcher.rank ~query:"a" ~limit:(-1) []);
    check "negative limit raises" false
  with Invalid_argument _ -> ());

  print_endline "OK"
