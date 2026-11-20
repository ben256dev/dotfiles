#!/bin/sh
# Copy mode's P: pin the selected lines at the top of a new tab and open v
# below them (.tmux.conf binds it).
#
#   pin-v.sh DIR            read the selection on stdin and open the tab,
#                           with v started in DIR
#   pin-v.sh --show FILE    the top pane: the lines, in less (q unpins them)
#   pin-v.sh --run FILE     the bottom pane: v, then close the tab
#
# v prints a diff of what you edited after Neovim exits. Closing the tab at
# once would throw that away, so when v saved a new diff the tab waits for a
# key first.

case ${1:-} in
--show)
    exec less -S -~ -Ps"pinned (q unpins)" "$2"
    ;;
--run)
    index=${XDG_STATE_HOME:-$HOME/.local/state}/v/diffs/index.tsv
    before=$(tail -n 1 "$index" 2>/dev/null)
    v
    if [ "$(tail -n 1 "$index" 2>/dev/null)" != "$before" ]; then
        printf '\nPress any key to close'
        bash -c 'read -rsn1'
    fi
    rm -f "$2"
    exec tmux kill-window -t "$TMUX_PANE"
    ;;
esac

dir=$1
pin=$(mktemp "${TMPDIR:-/tmp}/tmux-pin.XXXXXX") || exit 1
cat > "$pin"
if [ ! -s "$pin" ]; then
    rm -f "$pin"
    exit 0
fi

# awk counts a last line without a newline too.
lines=$(awk 'END { print NR }' "$pin")

window=$(tmux new-window -P -F '#{window_id}' -n v -c "$dir" \
    "sh '$0' --run '$pin'")

# The lines plus less's prompt row, but at most half the tab.
height=$(tmux display -p -t "$window" '#{window_height}')
top=$((lines + 1))
[ "$top" -gt $((height / 2)) ] && top=$((height / 2))
tmux split-window -b -d -v -t "$window" -l "$top" "sh '$0' --show '$pin'"
