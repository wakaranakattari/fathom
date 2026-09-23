(** Suite for Config parsing invariants.
    Assertions cover default fallback on missing files, key value
    parsing with bounds, invalid value retention of defaults, and
    [FATHOM_CONFIG] precedence for path resolution. Temporary files
    are removed after the run. Runs under [dune test]. *)

(* Asserts [cond]. Prints label on failure and exits non-zero. *)
let check label cond =
  if not cond then begin
    Printf.eprintf "FAIL: %s\n%!" label;
    exit 1
  end

let () =
  (* Missing file yields defaults. *)
  let cfg = Config.load "/nonexistent/fathom_config_test" in
  check "default limit" (cfg.Config.limit = Config.default.Config.limit);
  check "default color" (cfg.Config.color = Config.default.Config.color);

  (* Key value parsing respects bounds and booleans. *)
  let path = Filename.temp_file "fathom_cfg" ".conf" in
  let oc = open_out path in
  output_string oc "# comment\nlimit = 10\ncolor = off\nhidden = yes\nunknown = 1\n";
  close_out oc;
  let loaded = Config.load path in
  check "limit parsed" (loaded.Config.limit = 10);
  check "color parsed" (loaded.Config.color = false);
  check "hidden parsed" (loaded.Config.hidden = true);
  Sys.remove path;

  (* Invalid values keep defaults. *)
  let bad = Filename.temp_file "fathom_bad" ".conf" in
  let ocb = open_out bad in
  output_string ocb "limit = -5\ncolor = maybe\n";
  close_out ocb;
  let kept = Config.load bad in
  check "bad limit kept" (kept.Config.limit = Config.default.Config.limit);
  check "bad color kept" (kept.Config.color = Config.default.Config.color);
  Sys.remove bad;

  (* Default path respects FATHOM_CONFIG. *)
  Unix.putenv "FATHOM_CONFIG" "/tmp/fathom_custom_conf";
  check "env path wins" (Config.default_path () = "/tmp/fathom_custom_conf");
  print_endline "OK"
