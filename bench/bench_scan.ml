(** Micro benchmark over walk, rank, and content search stages.
    The root and query take optional argv positions with defaults of
    [.] and [main]. Each stage reports item counts with wall time.
    Timings suit relative comparison across runs on one machine. *)

let time f =
  let start = Unix.gettimeofday () in
  let result = f () in
  let stop = Unix.gettimeofday () in
  (result, stop -. start)

let () =
  let root = if Array.length Sys.argv > 1 then Sys.argv.(1) else "." in
  let query = if Array.length Sys.argv > 2 then Sys.argv.(2) else "main" in
  let (files, walk_time) = time (fun () -> Scan.walk_ex ~hidden:false ~no_ignore:false [ root ]) in
  Printf.printf "walk: %d files in %.3f s (root=%s)\n%!"
    (List.length files) walk_time root;
  let (ranked, rank_time) =
    time (fun () -> Matcher.rank ~query ~limit:50 files)
  in
  Printf.printf "rank: %d results in %.3f s (query=%s)\n%!"
    (List.length ranked) rank_time query;
  let (matches, search_time) =
    time (fun () -> Search.search ~query ~paths:files ~limit:50)
  in
  Printf.printf "search: %d matches in %.3f s (query=%s)\n%!"
    (List.length matches) search_time query
