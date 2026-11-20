#!/bin/sh
# Copy mode's P: pin the selected lines at the top of a new tab and open v
# below them (.tmux.conf binds it).
#
#   pin-v.sh PANE START END HISTORY DIR
#                           copy lines START to END of PANE and open the tab,
#                           with v started in DIR
#   pin-v.sh --show FILE    the top pane: the lines, in less (q unpins them)
#   pin-v.sh --run FILE     the bottom pane: v, then close the tab
#
# The lines come from the pane itself (capture-pane -e), not from the copied
# text, so they keep their colours; the selection only picks which whole
# lines. START and END count from the top of the scrollback, as tmux's
# selection_start_y and selection_end_y do; HISTORY is the scrollback's size.
#
# v prints a diff of what you edited after Neovim exits. Closing the tab at
# once would throw that away, so when v saved a new diff the tab waits for a
# key first.

case ${1:-} in
--show)
    exec less -R -S -~ -Ps"pinned (q unpins)" "$2"
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

pane=$1 start=$2 end=$3 history=$4 dir=$5
# No selection: tmux leaves the selection formats empty.
[ -n "$start" ] && [ -n "$end" ] || exit 0
[ "$start" -gt "$end" ] && { t=$start; start=$end; end=$t; }

pin=$(mktemp "${TMPDIR:-/tmp}/tmux-pin.XXXXXX") || exit 1
# capture-pane counts the visible screen from 0 and the scrollback above it
# in negatives. -J joins wrapped lines (less -S shows them unwrapped). Each
# line ends with a reset, so a colour left on doesn't spill into the next.
tmux capture-pane -p -e -J -t "$pane" -S $((start - history)) -E $((end - history)) |
    sed 's/$/\x1b[0m/' > "$pin"

# awk counts a last line without a newline too.
lines=$(awk 'END { print NR }' "$pin")

window=$(tmux new-window -P -F '#{window_id}' -n v -c "$dir" \
    "sh '$0' --run '$pin'")

# The lines plus less's prompt row, but at most half the tab.
height=$(tmux display -p -t "$window" '#{window_height}')
top=$((lines + 1))
[ "$top" -gt $((height / 2)) ] && top=$((height / 2))
tmux split-window -b -d -v -t "$window" -l "$top" "sh '$0' --show '$pin'"
