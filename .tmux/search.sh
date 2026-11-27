#!/usr/bin/env bash
# Copy mode's / and ? prompt, typed where the cursor is instead of in the
# status line: .tmux.conf opens this in a one-line popup at the cursor, and
# it searches as you type, like command-prompt -i.
#   search.sh open forward|backward PANE CLIENT   open the popup
#   search.sh forward|backward PANE                the prompt, in the popup
# Enter keeps the match (n and N go on from it), Escape or Ctrl+c goes back
# to where the search started. Backspace, Ctrl+w and Ctrl+u edit.
set -u

if [ "$1" = open ]; then
    dir=$2 pane=$3 client=$4
    # From the cursor to the pane's right edge (the popup can't take its
    # width as a format). -x and -y are the popup's top left.
    read -r x y w < <(tmux display -p -t "$pane" \
        '#{copy_cursor_x} #{copy_cursor_y} #{e|-:#{pane_width},#{copy_cursor_x}}')
    exec tmux display-popup -c "$client" -t "$pane" -B -E -h 1 -w "$w" \
        -x "#{e|+:#{popup_pane_left},$x}" -y "#{e|+:#{popup_pane_top},$y}" \
        "bash ~/.tmux/search.sh $dir $pane"
fi

dir=$1 pane=$2
[ "$dir" = forward ] && mark=/ || mark='?'
text=""

search() { tmux send -t "$pane" -X "search-$dir-incremental" "=$1"; }
draw() { printf '\r%s%s\033[K' "$mark" "$text"; }
# An empty search puts the cursor back where it started and clears the marks.
cancel() { search ""; exit 0; }
trap cancel INT

search ""
draw
while IFS= read -rsn1 -d '' k; do
    case $k in
    $'\n' | $'\r') exit 0 ;;
    $'\033')
        # A key like an arrow sends more after the Escape; ignore those.
        IFS= read -rsn8 -t 0.01 -d '' rest || true
        [ -z "${rest:-}" ] && cancel
        continue
        ;;
    $'\177' | $'\b')
        [ -z "$text" ] && cancel # like Vim, Backspace on nothing gives up
        text=${text%?}
        ;;
    $'\027') text=$(printf %s "$text" | sed 's/[^ ]*[ ]*$//') ;;
    $'\025') text="" ;;
    [[:cntrl:]]) continue ;;
    *) text+=$k ;;
    esac
    draw
    search "$text"
done
