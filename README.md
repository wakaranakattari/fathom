# fathom

![version](https://img.shields.io/badge/version-0.1.0-blue)
![OCaml](https://img.shields.io/badge/OCaml-5.5-orange)
![build](https://img.shields.io/badge/build-dune_3-green)
![platform](https://img.shields.io/badge/platform-linux_macos_windows-lightgrey)

File and content search in a single static binary. Zero runtime dependencies beyond the system C library.

Contents:

- [Features](#features)
- [Install](#install)
- [Usage](#usage)
- [Options](#options)
- [Interactive mode](#interactive-mode)
- [Output formats](#output-formats)
- [Ranking](#ranking)
- [Configuration](#configuration)
- [History](#history)
- [Git integration](#git-integration)
- [Clipboard](#clipboard)
- [Project structure](#project-structure)
- [Tests and benchmarks](#tests-and-benchmarks)
- [Design notes](#design-notes)
- [Version](#version)

## Features

- File name search with substring and fuzzy matching.
- Content search with file paths, 1-based line numbers, and byte columns.
- Live terminal UI with result list and file preview.
- Plain numbered prompt as fallback for pipes and non-TTY contexts.
- Preview pane with match highlight, context lines, and line numbers.
- Stable plain and JSON output for scripts.
- Access history with recency and frequency boosts.
- Git status boosts for modified, added, and untracked files.
- Ignore support for `.gitignore`, `.ignore`, and `.fdignore`.
- Hidden file control and absolute or relative path display.
- Config file with command line overrides.
- Clipboard copy through standard system tools.
- Direct action on results: open in editor or run a command.
- Parallel directory walk over multiple roots.
- Single binary built from OCaml with Stdlib plus Unix only.

## Install

Prerequisites:

- OCaml 5.x
- opam 2.x
- dune 3.x

Build from source:

```sh
eval $(opam env --switch=system)
dune build
dune test
```

Install to `~/.local/bin`:

```sh
dune build --release
install -Dm755 _build/default/bin/main.exe ~/.local/bin/fathom
```

Verify:

```sh
fathom --version
fathom --help
```

`~/.local/bin` is expected on PATH. When the shell reports
`command not found`, append the export below to `~/.bashrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Remove:

```sh
rm ~/.local/bin/fathom
```

## Usage

Syntax:

```sh
fathom [QUERY] [ROOTS...] [options]
```

A standalone `--` token is accepted anywhere and ignored. The forms
below are equivalent:

```sh
fathom main --print --limit 5
fathom -- main --print --limit 5
```

Search modes:

| Flag      | Scope                          |
|-----------|--------------------------------|
| `--files` | File names only                |
| `--text`  | File contents only             |
| `--mixed` | Names and contents (default)   |

Common invocations:

```sh
fathom main --print --limit 10 --relative
fathom main --files --print
fathom rank --text --print --limit 20
fathom main --json --limit 5
fathom main --preview --limit 1 --relative --no-color
fathom main --exec nvim
fathom main --copy
fathom query lib bin --print
fathom main --root lib --root bin --print
EDITOR=nvim fathom main
```

When stdout is not a TTY and neither `--print` nor `--json` is given,
results print in plain form for script use.

## Options

| Flag                | Effect                                          |
|---------------------|-------------------------------------------------|
| `--print`           | Print results and exit                          |
| `--json`            | Print results as JSON and exit                  |
| `--files`           | Search file names only                          |
| `--text`            | Search file contents only                       |
| `--mixed`           | Search names and contents (default)             |
| `--exec CMD`        | Run CMD with the selected file appended         |
| `--copy`            | Copy the selected path to the clipboard         |
| `--preview`         | Append preview of the top result in print mode  |
| `--limit N`         | Maximum results, 1 to 1000 (default 50)         |
| `--root DIR`        | Root to scan, repeatable (default `.`)          |
| `--preview-lines N` | Preview lines in TUI, 1 to 100 (default 12)     |
| `--context N`       | Context lines around a match, 0 to 20 (default 3) |
| `--color`           | Force color output                              |
| `--no-color`        | Disable color output                            |
| `--hidden`          | Include hidden files                            |
| `--no-hidden`       | Skip hidden files (default)                     |
| `--absolute`        | Print absolute paths                            |
| `--relative`        | Print paths relative to cwd (default)           |
| `--line-numbers`    | Show line numbers in preview (default)          |
| `--no-line-numbers` | Hide line numbers in preview                    |
| `--no-ignore`       | Skip ignore files                               |
| `--no-history`      | Disable history read and write                  |
| `--config PATH`     | Config file path                                |
| `--version`         | Print version and exit                          |
| `--help`            | Print usage and exit                            |

Color is also disabled when `NO_COLOR` is set or when `TERM` is `dumb`.

## Interactive mode

Interactive mode starts when stdout is a TTY and neither `--print`
nor `--json` is given. The file list is scanned once at startup.
Ranking updates on each keystroke.

Keys:

| Key                | Action                              |
|--------------------|-------------------------------------|
| Type               | Update query, reset selection       |
| Backspace          | Delete last query character         |
| Up, Down           | Move selection                      |
| Ctrl-P, Ctrl-N     | Move selection                      |
| Enter              | Open in editor or run `--exec`      |
| Ctrl-Y             | Copy current path to clipboard      |
| Ctrl-U             | Clear query                         |
| Esc, Ctrl-C        | Quit without action                 |

The preview pane shows the focus line with surrounding context. Focus
is the first match of the query, or the file head for empty queries.
A numbered prompt replaces the live view for pipes. It prints up to
20 results and reads an index. Input `y` copies the top result. Empty
input quits.

## Output formats

Plain results use `index TAB score TAB path`:

```text
1	29.95	bin/main.ml
2	7.63	bin/dune
```

JSON results carry `index`, `score`, and `path` fields:

```json
[
  {"index": 1, "score": 29.95, "path": "bin/main.ml"}
]
```

Text search in print mode uses `path:line:col:text`:

```text
README.md:34:20:Features
```

Matches highlight with ANSI bold red unless color is disabled. Long
lines truncate to a fixed width.

## Ranking

Score order for non-empty queries:

1. Substring match in path, with bonus for basename matches.
2. Fuzzy fallback with ordered characters and gap penalties.
3. History boost from recency and frequency.
4. Git boost for modified, added, and untracked files.

Ties resolve by path. Output truncates to `--limit`. Empty queries
list scanned files in sorted order with history and git boosts
applied.

Traversal prunes `.git`, `_build`, `node_modules`, `.hg`, `_opam`,
and `.lsp` in every directory. Symlinked directories are listed but
not followed. Files above 1 MB and binary files skip content search.

## Configuration

Location order:

1. `--config PATH` explicit value.
2. `$FATHOM_CONFIG` when set and non-empty.
3. `$XDG_CONFIG_HOME/fathom/config`.
4. `$HOME/.config/fathom/config`.

Format is line based `key = value`. Blank lines and `#` comments are
skipped. Unknown keys are ignored. Command line flags override file
values.

| Key             | Type    | Range              | Default |
|-----------------|---------|--------------------|---------|
| `limit`         | integer | 1 to 1000          | 50      |
| `preview_lines` | integer | 1 to 100           | 12      |
| `context`       | integer | 0 to 20            | 3       |
| `color`         | boolean | true or false      | true    |
| `hidden`        | boolean | true or false      | false   |
| `absolute`      | boolean | true or false      | false   |
| `line_numbers`  | boolean | true or false      | true    |
| `no_ignore`     | boolean | true or false      | false   |
| `no_history`    | boolean | true or false      | false   |

Booleans accept `true`, `false`, `1`, `0`, `yes`, `no`, `on`, `off`
case-insensitively. Out of range integers keep prior values.

Example:

```text
# Preferred defaults
limit = 30
preview_lines = 12
context = 3
color = true
hidden = false
absolute = false
line_numbers = true
```

## History

History maps paths to access counts and timestamps. Storage is tab
separated text. Location respects `$XDG_CACHE_HOME` with fallback to
`$HOME/.cache/fathom/history.tsv`. Reads tolerate missing files and
malformed lines. Writes create parent directories and ignore errors.
`--no-history` disables both directions.

## Git integration

Inside a repository, status comes from `git status --porcelain` with
capped output. Modified paths rank above added paths, which rank above
untracked paths. Outside a repository, or when git is unavailable,
status is empty and ranking is unchanged.

## Clipboard

Copy probes tools in fixed order: `wl-copy`, `xclip`, `xsel`,
`pbcopy`, `clip.exe`. Text pipes to tool stdin. Missing tools leave
the path on stdout with a notice on stderr.

## Project structure

```text
bin/            Entry point, argument parsing and wiring only
lib/scan/       Directory walk, ignore files, display paths
lib/match/      Pure ranking without IO
lib/search/     Content search with line granularity
lib/preview/    File preview with ANSI highlight
lib/git/        Repository status for boosts
lib/config/     File options with validation
lib/clip/       Clipboard tool detection
lib/tui/        Live view with plain fallback
lib/ui/         Stable print and JSON for scripts
test/           Suites for match, search, config, preview
bench/          Walk, rank, and search latency on a tree
doc/            Architecture, usage, config, style
```

Every library module ships a `.mli` contract. `Matcher` stays pure.
IO lives in `Scan`, `Search`, `History`, `Git`, and output modules.

## Tests and benchmarks

```sh
dune test
dune exec ./bench/bench_scan.exe -- . main
```

Suites cover ranking order, substring and fuzzy scoring, content
search line numbers, config parsing with invalid input, and preview
highlight with first match lines. The benchmark reports walk time
with file count, rank time with result count, and content search time
with match count on the given tree.

## Design notes

- One static binary with no runtime package dependencies.
- Deterministic walk from sorted directory reads.
- Ranking split from IO for direct unit tests.
- Display conversion kept at output edges only.
- Terminal state restored on every exit path of the live view.
- Best effort policy for history, git, and clipboard state.

## Version

0.1.0
