#!/bin/sh
# The Alt+H cheatsheet: tmux's Alt bindings with their -N notes (.tmux.conf).
#   cheatsheet.sh CLIENT    open the popup on CLIENT, sized to fit
#   cheatsheet.sh --print   print the list (what the popup shows)

# The order to list keys in: tabs, splits and panes, then the rest. tmux
# lists bindings by key, so this puts related ones together. A key missing
# here still shows, at the end.
order='c r 1 s v m z x y h'

list() {
    tmux list-keys -N -T root | awk -v order="$order" '
        BEGIN { n = split(order, keys, " "); for (i = 1; i <= n; i++) rank[keys[i]] = i }
        /^M-/ {
            key = substr($1, 3); note = $0; sub(/^[^ ]+ +/, "", note)
            # Alt+1 ... Alt+9 become one line, and so do the four pane moves.
            if (key ~ /^[1-9]$/) {
                if (tabs++) next
                key = "1-9"; sub(/ [1-9]$/, " 1-9", note); r = rank["1"]
            } else if (key ~ /^[mnei]$/) {
                if (panes++) next
                key = "mnei"; note = "Move panes ←↓↑→"; r = rank["m"]
            } else {
                r = (key in rank) ? rank[key] : n + 1
            }
            printf "%03d\tAlt+%s\t%s\n", r, key, note
        }' | sort -s -k1,1n | cut -f2- |
        # Line the notes up two spaces after the longest key, and give every
        # line a space of padding on the left.
        awk -F '\t' '{ key[NR] = $1; note[NR] = $2; if (length($1) > w) w = length($1) }
            END { for (i = 1; i <= NR; i++) printf " %-*s  %s\n", w, key[i], note[i] }'
}

if [ "${1:-}" = --print ]; then
    # No final newline: it would leave the cursor on an empty last row.
    printf '%s' "$(list)"
    exit 0
fi

lines=$(list)
rows=$(printf '%s\n' "$lines" | wc -l)
# Width in characters, not bytes: drop UTF-8 continuation bytes (the arrows
# are three bytes each) before measuring.
cols=$(printf '%s\n' "$lines" | LC_ALL=C sed 's/[\x80-\xbf]//g' |
    awk '{ if (length > w) w = length } END { print w }')
# Plus a space of padding on the right (the left one is in the list) and the
# border. tmux centres the title over that width.
tmux display-popup -c "$1" -T '#[align=centre] tmux cheatsheet ' \
    -w $((cols + 3)) -h $((rows + 2)) \
    -E "sh ~/.tmux/cheatsheet.sh --print; bash -c 'read -rsn1'"
