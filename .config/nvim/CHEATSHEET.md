# Neovim Cheatsheet

You may write and close this Cheatsheet just like any other file.

## Visual selection

Select text with `V` first.

- `:y+` / `"+y` — copy the selection to the system clipboard
- `:w !bash` — run the selected lines as an external Bash command
- `:!sort` — sort selected lines alphabetically

## Normal mode

- `,c` `,sh` `,py` `,html` `,mainc` `,go` `,c3` — common language skeletons

## Insert mode

- `,fi` or `,if` — creates a brace block
- `><` — type after HTML tag: `b><` becomes `<b></b>`

## LSP

- `Ctrl-n` / `Ctrl-p` — select next / previous suggestion
- `Ctrl-y` — accept the selected suggestion
- `Ctrl-Space` — open suggestions
- `Ctrl-e` — close suggestions
- `Ctrl-b` / `Ctrl-f` — scroll suggestion documentation

- `Ctrl-w d` — show the warning or error under the cursor
- `]d` — jump to the next one
- `[d` — jump to the previous

## Files, Buffers, and History

- `Space b` — find an open buffer
- `Space f` — find a file
- `Space g` — find a Git-tracked file
- `Space h :` — command history
- `Space h /` — search history

## Neovim Windows

- `Ctrl-w` + `m` — move to the window on the left
- `Ctrl-w` + `n` — move to the window below
- `Ctrl-w` + `e` — move to the window above
- `Ctrl-w` + `i` — move to the window on the right

## Browser-inspired Buffers

- `Ctrl-Tab` — move one tab to the right
- `Ctrl-Shift-Tab` — move one tab to the left

## Miscellaneous

- `Space t t` — toggle transparent background
- `Space l l` — toggle light / dark color scheme
- `Space ?` — open this cheatsheet

## Plugins

I rarely use these

- `:Git` — opens fugitive plugin
- `ga` — EasyAlign plugin
