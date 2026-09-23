(lang dune 3.0)
(name fathom)
(generate_opam_files true)

(package
 (name fathom)
 (allow_empty)
 (synopsis "Fast file and content search in a single binary")
 (description "Interactive search over file names and file contents with ranking, preview, and actions.")
 (depends ocaml dune))
