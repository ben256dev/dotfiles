# Neovim Cheatsheet

`Leader` is `Space`.

## Visual selection

Select text with `v` first.

- `"+y` — copy the selection to the system clipboard
- `:w !bash` — run the selected lines as an external Bash command

## Completion

- `Ctrl-n` / `Ctrl-p` — select next / previous suggestion
- `Ctrl-y` — accept the selected suggestion
- `Ctrl-Space` — open suggestions
- `Ctrl-e` — close suggestions
- `Ctrl-b` / `Ctrl-f` — scroll suggestion documentation

## Finding files and buffers

- `Space b` — find an open buffer
- `Space f` — find a file
- `Space g` — find a Git-tracked file
- `Space h :` — command history
- `Space h /` — search history

## Windows

- `Ctrl-Left` — move to the window on the left
- `Ctrl-Down` — move to the window below
- `Ctrl-Up` — move to the window above
- `Ctrl-Right` — move to the window on the right

## Tabs

- `g t` — move to the next tab
- `g T` — move to the previous tab
- `{number} g t` — move to a specific numbered tab

## Miscellaneous

- `Space t t` — toggle transparent background
- `Space ?` — open this cheatsheet
- `:q` — close the cheatsheet and remove its buffer
