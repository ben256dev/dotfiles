#!/usr/bin/env bash
# Vim's operators, motions and text objects in tmux's copy mode, worked out
# by Neovim itself (.tmux/vim.lua) over the lines around the cursor:
#   y with no selection   y t :, y 3 w, y i {, y / foo Enter, y y: copies
#   i or a                v i ' (or just i '), v a p: selects
# With a selection, y copies it, as before. The keys typed so far show at
# the top right; Escape (or an Alt key) cancels.
#   vim.sh bind                       bind the keys (from .tmux.conf)
#   vim.sh start KEYS PANE CLIENT     y, i or a (KEYS y, vi or va)
#   vim.sh key KEY PANE CLIENT        a key typed while Vim waits for more
#
# While Vim waits, every key is bound in the vim key table, and this script
# switches the client to it before it returns. tmux holds keys pressed in
# the meantime until run-shell finishes, so however fast they're typed,
# each is looked up in the vim table, in order. (That's also why y runs
# this directly rather than through if -F, which doesn't hold them.)
set -u
self=~/.tmux/vim.sh

if [ "$1" = bind ]; then
    run() { printf 'bash %s %s #{pane_id} #{client_name}' "$self" "$1"; }
    # The commands go to tmux in batches: it refuses one that's too long.
    cmd=()
    flush() { [ "${#cmd[@]}" = 0 ] || tmux "${cmd[@]}"; cmd=(); }
    add() {
        [ "${#cmd[@]}" = 0 ] || cmd+=(\;)
        cmd+=("$@")
        [ "${#cmd[@]}" -lt 150 ] || flush
    }
    add bind -T copy-mode-vi y run-shell "$(run 'start y')"
    add bind -T copy-mode-vi i run-shell "$(run 'start vi')"
    add bind -T copy-mode-vi a run-shell "$(run 'start va')"
    # Printable characters go to the script by their codes, which need no
    # quoting. (A bare ; would end tmux's command here, so it's \;.)
    for ((c = 33; c < 127; c++)); do
        printf -v k "\\$(printf %03o "$c")"
        [ "$k" = ';' ] && k='\;'
        add bind -T vim "$k" run-shell "$(run "key $c")"
    done
    # Then the named keys: Space, Enter, Tab and Ctrl keys go to Vim;
    # Escape and Ctrl+c cancel; arrows, F keys and Alt keys cancel and then
    # do what they usually do (Alt+h still splits).
    for k in Space Enter Tab BSpace Escape C-{a..z} Up Down Left Right Home End \
        PPage NPage DC IC F{1..12} M-{a..z} M-{0..9} 'M-?' M-/ M-Enter M-Space; do
        case $k in C-i | C-m) continue ;; esac # Tab and Enter
        add bind -T vim "$k" run-shell "$(run "key $k")"
    done
    # Anything else (a click) leaves the vim table without a word: the
    # keys are forgotten when copy mode starts or ends (.tmux.conf's
    # pane-mode-changed hook), so they don't linger at the top right.
    flush
    exit 0
fi

action=$1
if [ "$action" = start ]; then
    keys=$2 pane=$3 client=$4
    if [ "$keys" = y ] && [ "$(tmux display -p -t "$pane" '#{selection_present}')" = 1 ]; then
        exec tmux send -X -t "$pane" copy-pipe-and-cancel "sh ~/.tmux/copy.sh"
    fi
else
    key=$2 pane=$3 client=$4
    keys=$(tmux show -pqv -t "$pane" @vim_keys)
    # tmux's keys into Vim's notation.
    case $key in
    BSpace)
        # Take back the last key, but not the y, i or a that started it.
        if [[ $keys =~ ^(.*)\<[^\<\>]+\>$ ]]; then keys=${BASH_REMATCH[1]}; else keys=${keys%?}; fi
        [ "${#keys}" -ge "$([ "${keys:0:1}" = v ] && echo 2 || echo 1)" ] || keys=""
        key=""
        ;;
    60) key='<lt>' ;;
    [0-9]*) printf -v key "\\$(printf %03o "$key")" ;;
    Space) key='<Space>' ;;
    Enter) key='<CR>' ;;
    Escape | C-c) keys="" key="" ;;
    M-* | Up | Down | Left | Right | Home | End | PPage | NPage | DC | IC | F*)
        tmux set -pu -t "$pane" @vim_keys \; send-keys -K -c "$client" "$key"
        exit 0
        ;;
    *) key="<$key>" ;;
    esac
    keys+=$key
fi

stop() { tmux set -pu -t "$pane" @vim_keys; exit 0; }
[ -n "$keys" ] || stop
tmux set -p -t "$pane" @vim_keys "$keys"

wait_for_more() {
    tmux switch-client -c "$client" -T vim
    exit 0
}
# y, vi and va always want more; no need to ask Vim.
[ "$action" = start ] && wait_for_more

read -r x y scroll width < <(tmux display -p -t "$pane" \
    '#{copy_cursor_x} #{copy_cursor_y} #{scroll_position} #{pane_width}') || stop

# The lines around the cursor, from copy mode's screen (-M), wrapped rows
# joined (-J). Captured twice: plainly, and with -L numbering each line by
# its first row, to find the cursor's line and where on it the cursor is
# (rows are width wide; wide characters would throw that off).
row=$((y - scroll))
range=(-M -p -J -t "$pane" -S $((row - 300)) -E $((row + 300)))
mapfile -t captured < <(tmux capture-pane "${range[@]}" \; capture-pane -L "${range[@]}")
half=$((${#captured[@]} / 2))
first=()
lnum=0
for ((i = 0; i < half; i++)); do
    first[i]=${captured[half + i]%% *}
    [ "${first[i]}" -le "$row" ] && lnum=$((i + 1)) vcol=$(((row - first[i]) * width + x + 1))
done
[ "$lnum" -gt 0 ] || stop

lines=$(mktemp)
trap 'rm -f "$lines"' EXIT
printf '%s\n' "${captured[@]:0:half}" > "$lines"
result=$(timeout 2 nvim -l ~/.tmux/vim.lua "$lines" "$lnum" "$vcol" "$keys") || result=none

[ "$result" = pending ] && wait_for_more
tmux set -pu -t "$pane" @vim_keys

case $result in
yank*)
    text=${result#yank$'\n'}
    printf '%s' "$text" | tmux load-buffer -
    # xclip stays to serve the clipboard: with run-shell's output still
    # open, run-shell would never finish, and hold up the client's keys.
    printf '%s' "$text" | sh ~/.tmux/copy.sh >/dev/null 2>&1
    tmux send -X -t "$pane" cancel
    ;;
select*)
    read -r _ mode l1 v1 l2 v2 <<< "$result"
    # Move from row to line l's first row, to its start, then right to
    # column v (cursor-right carries on through the line's wrapped rows).
    to() {
        local d=$((first[$1 - 1] - row))
        if [ "$d" -lt 0 ]; then cmd+=(\; send -X -t "$pane" -N $((-d)) cursor-up)
        elif [ "$d" -gt 0 ]; then cmd+=(\; send -X -t "$pane" -N "$d" cursor-down)
        fi
        cmd+=(\; send -X -t "$pane" start-of-line)
        [ "$2" -gt 1 ] && cmd+=(\; send -X -t "$pane" -N $(($2 - 1)) cursor-right)
        row=$((first[$1 - 1] + ($2 - 1) / width))
    }
    cmd=(send -X -t "$pane" clear-selection)
    if [ "$mode" = line ]; then
        # select-line takes the cursor to the line's end: select the last
        # line, go back to its start with other-end, then up to the first.
        [ "$l1" -le "$l2" ] || { t=$l1; l1=$l2; l2=$t; }
        to "$l2" 1
        cmd+=(\; send -X -t "$pane" select-line \; send -X -t "$pane" other-end)
        row=${first[l2 - 1]}
        [ "$l1" = "$l2" ] || to "$l1" 1
    else
        to "$l1" "$v1"
        cmd+=(\; send -X -t "$pane" begin-selection)
        [ "$mode" = block ] && cmd+=(\; send -X -t "$pane" rectangle-on)
        to "$l2" "$v2"
    fi
    tmux "${cmd[@]}"
    ;;
esac
