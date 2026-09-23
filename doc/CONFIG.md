# Config

Location order:

1. `--config PATH` explicit value.
2. `$FATHOM_CONFIG` when set and non-empty.
3. `$XDG_CONFIG_HOME/fathom/config`.
4. `$HOME/.config/fathom/config`.

Format is line based `key = value`. Blank lines and `#` comments are
skipped. Unknown keys are ignored. CLI flags override file values.

Keys:

```text
limit = 50
preview_lines = 12
context = 3
color = true
hidden = false
absolute = false
line_numbers = true
no_ignore = false
no_history = false
```

Booleans accept `true`, `false`, `1`, `0`, `yes`, `no`, `on`, `off`
case-insensitively. Integers outside documented ranges are ignored.

Example:

```text
# Preferred defaults
limit = 30
color = true
hidden = false
absolute = false
context = 3
```
