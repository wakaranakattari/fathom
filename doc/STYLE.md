# Style

## Language

All source, docs, and commit messages use English only. Breaks and
ranges use hyphen - only. Codepoints U+2013 and U+2014 are rejected
in CI.

## Comments

- `(* *)` in `.ml` for invariants, rationale, and complexity.
- `(** *)` in `.mli` for interface contracts with ocamldoc tags.
- Impersonal present tense. State contract and limits.
- No first person. No marketing adjectives. No filler such as simply
  or just. No em dash. No en dash.

Good:

```ocaml
(* Walk roots in parallel. Returns normalized absolute paths. *)
(* Complexity is O(n log n) in number of entries where n is file count. *)
(* Invariant: caller provides normalized roots. Symlinks are not followed. *)
```

Bad:

```ocaml
(* This function walks roots and it is super fast and simple *)
```

## Interfaces

Every `.ml` has a matching `.mli` except `bin/main.ml` and tests.
Public functions document params, return values, errors, and limits
with `@param`, `@return`, and `@raise` tags.

## Formatting

- One module per directory for `lib`.
- No logic in `bin` beyond parsing and wiring.
- Pure functions in `Matcher`. IO only in `Scan`, `History`, `Plain`.
