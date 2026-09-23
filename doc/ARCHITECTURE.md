# Architecture

## Goals

- Single static binary for common search flows.
- Deterministic behavior for scripts.
- Pure ranking separated from IO and UI.

## Modules

### Scan

Traversal uses sorted directory reads. Pruning precedes recursion.
Symlinked directories are listed but not followed. Ignore rules cover
`.gitignore`, `.ignore`, and `.fdignore` with basename and suffix
checks. Hidden entries are skipped unless requested. Multiple roots
are walked in parallel with Domains. Output paths are absolute
internally and converted for display with `to_display`.

### Match

Scoring combines substring and fuzzy fallback. Substring matches
dominate. Fuzzy scoring requires ordered characters and penalizes gaps
and long paths. Ranking sorts by score then path and truncates to limit.

### Search

Content search reads up to 1MB per file and skips binary prefixes.
Matching is case-insensitive ASCII over lines. Results carry 1-based
line numbers and byte columns. Long lines are truncated.

### Preview

Rendering finds the first match line and prints context around it.
Query occurrences are wrapped in ANSI bold red when color is enabled.
Missing files yield a placeholder. Width is capped for stable layout.

### Git

Status comes from `git status --porcelain` with capped output. Paths
are resolved against the toplevel. Modified files boost most, then
added, then untracked. Failures yield empty status.

### Config

File options use `key = value` lines. CLI flags override file values.
Bounds are validated. Unknown keys are ignored.

### Clip

Clipboard probes `wl-copy`, `xclip`, `xsel`, `pbcopy`, and `clip.exe`
in order. Operations pipe text to stdin and check exit codes.

### Tui

Live view uses raw terminal mode with restore on exit. Ranking is
recomputed per keystroke over the cached file list. Escape sequences
are parsed with a short select timeout. Non-TTY contexts use a plain
numbered prompt.

### UI

Plain output uses `index TAB score TAB path` for stable parsing. JSON
output escapes strings per spec. Line matches print as
`path:line:col:text` with optional highlight.

## Data flow

```text
roots -> Scan.walk_ex -> files
files + query -> Matcher.rank -> ranked
ranked + History.boost + Git.boost -> sorted
sorted -> Plain.print or Tui.run
select -> History.record -> History.save
select -> editor or exec or clipboard
```

## Cross platform notes

Only `Sys`, `Filename`, and `Unix` are used. Path construction uses
`Filename.concat`. Cache location respects `XDG_CACHE_HOME` with
fallback to `$HOME/.cache`. Config respects `XDG_CONFIG_HOME` with
fallback to `$HOME/.config`. Clipboard tools are probed per OS.
Linux, macOS, and Windows share the same module paths.
