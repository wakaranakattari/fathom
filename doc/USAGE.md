# Usage

## Modes

- Mixed (default): file names ranked first, content matches appended.
- Files (`--files`): names only.
- Text (`--text`): contents only. Print mode shows `path:line:col:text`.

## Interactive

Live view starts on TTY without `--print` or `--json`.

Keys:

- Type: update query, reset selection to top.
- Backspace: delete last query char.
- Up, Down, Ctrl-P, Ctrl-N: move selection.
- Enter: open in `$EDITOR` or run `--exec` template.
- Ctrl-Y: copy current path via `wl-copy`, `xclip`, `xsel`, `pbcopy`.
- Ctrl-U: clear query.
- Ctrl-C, Esc: quit without action.

Preview shows the focus line with context. Focus is the first match
or the file head for empty queries. History and git boosts apply on
each keystroke.

Fallback prompt is used for pipes. It prints up to 20 results and
reads an index. Input `y` copies the top result. Empty input quits.

## Print

- `--print`: `index TAB score TAB path`.
- `--json`: array of `index`, `score`, `path` objects.
- `--relative` (default from config): strips cwd prefix.
- `--absolute`: keeps full paths.
- `--preview`: appends preview of the top result.
- `--no-color`: disables ANSI codes. `NO_COLOR` is respected.
- `--copy` with `--print`: copies top result after printing.
- `--exec CMD` with `--print`: runs `CMD` on top result after printing.

## Examples

```sh
fathom main --print --limit 5 --relative
fathom rank --text --print --limit 20 --no-color
fathom main --json --limit 3
fathom main --exec "nvim"
fathom main --copy
EDITOR=nvim fathom main
fathom query lib bin --print
fathom main --root lib --root bin --print
```
