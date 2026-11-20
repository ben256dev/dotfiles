#!/usr/bin/env bash
# Vim's text objects in tmux's copy mode (.tmux.conf): v i ' selects inside
# quotes, y a ( copies around brackets, y i w copies a word, as in Vim.
#   textobj.sh bind                      bind the keys (from .tmux.conf)
#   textobj.sh i|a OBJECT PANE [yank]    select (or copy) OBJECT at the cursor
#
# Objects: ' " ` (quotes), ( ) b, [ ], { } B, < > (brackets), w W (words).
# Only the cursor's line is looked at (wrapped rows count as one line), like
# Vim's quotes; brackets don't reach across lines either.
set -u

if [ "${1:-}" = bind ]; then
    self=~/.tmux/textobj.sh
    for kind in i a; do
        tmux bind -T copy-mode-vi "$kind" switch-client -T "textobj-$kind" \; \
            bind -T textobj-y "$kind" switch-client -T "textobj-y$kind"
        for obj in "'" '"' '`' '(' ')' b '[' ']' '{' '}' B '<' '>' w W; do
            q=$(printf '%q %q' "$kind" "$obj")
            tmux bind -T "textobj-$kind" "$obj" run-shell "bash $self $q '#{pane_id}'" \; \
                bind -T "textobj-y$kind" "$obj" run-shell "bash $self $q '#{pane_id}' yank"
        done
    done
    exit 0
fi

kind=$1 obj=$2 pane=$3 action=${4:-select}

read -r x y scroll width < <(tmux display -p -t "$pane" \
    '#{copy_cursor_x} #{copy_cursor_y} #{scroll_position} #{pane_width}') || exit 0

# The cursor's whole line, wrapped rows and all. copy_cursor_line is only
# the screen row, so capture copy mode's screen (-M) around it with wrapped
# rows joined (-J), twice: plainly, and with -L numbering each line by its
# first row, to find the line holding the cursor's row and where in it the
# cursor is (rows are width wide; wide characters would throw that off).
row=$((y - scroll))
range=(-M -p -J -t "$pane" -S $((row - 50)) -E $((row + 50)))
mapfile -t captured < <(tmux capture-pane "${range[@]}" \; capture-pane -L "${range[@]}")
half=$((${#captured[@]} / 2))
line=""
for ((i = 0; i < half; i++)); do
    first=${captured[half + i]%% *}
    next=${captured[half + i + 1]:-}; next=${next%% *}
    if [ "$first" -le "$row" ] && { [ $((i + 1)) = "$half" ] || [ "$next" -gt "$row" ]; }; then
        line=${captured[i]}
        x=$(((row - first) * width + x))
        break
    fi
done
n=${#line}
start=-1 end=-1 # inclusive

# Word classes, as Vim's w and W see them: 0 blank, 1 word, 2 punctuation.
class() {
    local c=${line:$1:1}
    if [[ $c == [[:space:]] ]]; then cls=0
    elif [ "$obj" = W ] || [[ $c == [[:alnum:]_] ]]; then cls=1
    else cls=2
    fi
}

# Grow end over the blanks after it; if there are none, grow start over the
# blanks before it instead. What Vim's a' and aw add.
add_blanks() {
    local e=$end
    while [ $((e + 1)) -lt "$n" ] && [[ ${line:$((e + 1)):1} == [[:space:]] ]]; do e=$((e + 1)); done
    if [ "$e" -gt "$end" ]; then
        end=$e
    else
        while [ "$start" -gt 0 ] && [[ ${line:$((start - 1)):1} == [[:space:]] ]]; do start=$((start - 1)); done
    fi
}

case $obj in
w | W)
    [ "$x" -lt "$n" ] || exit 0
    class "$x"; c=$cls
    start=$x end=$x
    while [ "$start" -gt 0 ] && class $((start - 1)) && [ "$cls" = "$c" ]; do start=$((start - 1)); done
    while [ $((end + 1)) -lt "$n" ] && class $((end + 1)) && [ "$cls" = "$c" ]; do end=$((end + 1)); done
    if [ "$kind" = a ]; then
        if [ "$c" = 0 ]; then
            # On blanks, aw is the blanks and the word after them.
            if [ $((end + 1)) -lt "$n" ]; then
                class $((end + 1)); c=$cls end=$((end + 1))
                while [ $((end + 1)) -lt "$n" ] && class $((end + 1)) && [ "$cls" = "$c" ]; do end=$((end + 1)); done
            fi
        else
            add_blanks
        fi
    fi
    ;;
"'" | '"' | '`')
    # Pair the line's quotes up from its start (skipping \-escaped ones), and
    # take the pair around the cursor, or else the next one after it.
    quotes=()
    for ((i = 0; i < n; i++)); do
        if [ "${line:i:1}" = '\' ]; then i=$((i + 1))
        elif [ "${line:i:1}" = "$obj" ]; then quotes+=("$i")
        fi
    done
    for ((j = 0; j + 1 < ${#quotes[@]}; j += 2)); do
        if [ "${quotes[j + 1]}" -ge "$x" ]; then
            start=${quotes[j]} end=${quotes[j + 1]}
            break
        fi
    done
    [ "$start" -ge 0 ] || exit 0
    if [ "$kind" = i ]; then
        start=$((start + 1)) end=$((end - 1))
    else
        add_blanks
    fi
    ;;
*)
    case $obj in
    '(' | ')' | b) open='(' close=')' ;;
    '[' | ']') open='[' close=']' ;;
    '{' | '}' | B) open='{' close='}' ;;
    '<' | '>') open='<' close='>' ;;
    esac
    # Back to the unmatched open bracket (a close bracket under the cursor
    # belongs to the pair, so it doesn't count), then on to its match.
    depth=0
    for ((i = x < n ? x : n - 1; i >= 0; i--)); do
        c=${line:i:1}
        if [ "$c" = "$close" ] && [ "$i" != "$x" ]; then depth=$((depth + 1))
        elif [ "$c" = "$open" ]; then
            [ "$depth" = 0 ] && { start=$i; break; }
            depth=$((depth - 1))
        fi
    done
    [ "$start" -ge 0 ] || exit 0
    depth=0
    for ((i = start + 1; i < n; i++)); do
        c=${line:i:1}
        if [ "$c" = "$open" ]; then depth=$((depth + 1))
        elif [ "$c" = "$close" ]; then
            [ "$depth" = 0 ] && { end=$i; break; }
            depth=$((depth - 1))
        fi
    done
    [ "$end" -ge 0 ] || exit 0
    [ "$kind" = a ] || { start=$((start + 1)) end=$((end - 1)); }
    ;;
esac

# Nothing inside (i' on ''): leave the selection as it was, as Vim does.
[ "$start" -le "$end" ] || exit 0

cmd=(send -X -t "$pane" clear-selection)
move=$((start - x))
if [ "$move" -lt 0 ]; then cmd+=(\; send -X -t "$pane" -N $((-move)) cursor-left)
elif [ "$move" -gt 0 ]; then cmd+=(\; send -X -t "$pane" -N "$move" cursor-right)
fi
cmd+=(\; send -X -t "$pane" begin-selection)
[ "$end" -gt "$start" ] && cmd+=(\; send -X -t "$pane" -N $((end - start)) cursor-right)
[ "$action" = yank ] && cmd+=(\; send -X -t "$pane" copy-pipe-and-cancel "sh ~/.tmux/copy.sh")
tmux "${cmd[@]}"
