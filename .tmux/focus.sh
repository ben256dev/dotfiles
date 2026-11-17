#!/bin/sh
# Unfocused terminals get a quieter status bar: just the session number and
# tabs as blue-grey text on the terminal's background (or Neovim's, when it's
# open in the active pane), no right side.
#   focus.sh in|out SESSION  from the client-focus-in/out hooks in .tmux.conf
#   focus.sh sync            after the theme loads: match every session to
#                            whether its terminal has focus right now
state=$1 session=$2

grey() {
    # One Dark's own blue-greys (#282c34, #3e4452, #aab2bf) stay as they are;
    # every other colour becomes a blue-grey of the same brightness, tinted
    # like One Dark's #abb2bf.
    perl -pe 's{#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})}{
        my @c = map { hex } ($1, $2, $3);
        my ($min, $max) = (sort { $a <=> $b } @c)[0, -1];
        my $l = .299*$c[0] + .587*$c[1] + .114*$c[2];
        $max - $min <= 24 ? "#$1$2$3"
            : sprintf("#%02x%02x%02x", map { my $v = int($l * $_ + .5); $v > 255 ? 255 : $v } .964, 1.003, 1.077)
    }gie'
}

# The theme's bar colour, before any session overrides it.
bar=$(tmux show -gv status-bg)

# Text only: every background becomes the terminal's, and the solid powerline
# arrows (which only draw block edges) become spaces, so the text sits in the
# same columns as when focused. The thin separators stay.
text_only() {
    perl -pe "s/bg=#[0-9a-f]{6}/bg=$bg/gi; s/\xee\x82[\xb0\xb2]/ /g"
}

focus_out() {
    windows=$(tmux list-windows -t "$1" -F '#{window_id}') || return 0
    # Match Neovim's background when it's open in the active pane (it sets
    # @editor_bg); otherwise the terminal's own.
    bg=$(tmux display -p -t "$1" '#{@editor_bg}')
    bg=${bg:-default}
    # The session badge's dark text would vanish on the terminal background,
    # so it takes the bar's text colour.
    tmux set -t "$1" status-left "$(tmux show -gv status-left | grey | sed "s/fg=$bar/fg=$(tmux show -gv status-fg)/" | text_only)"
    tmux set -t "$1" status-right ''
    # status-bg wins over status-style, so clear both.
    tmux set -t "$1" status-bg "$bg"
    tmux set -t "$1" status-style "bg=$bg,fg=$(tmux show -gv status-fg | grey)"
    for opt in window-status-format window-status-current-format; do
        value=$(tmux show -gwv "$opt" | grey | text_only)
        for window in $windows; do tmux set -w -t "$window" "$opt" "$value"; done
    done
}

focus_in() {
    windows=$(tmux list-windows -t "$1" -F '#{window_id}') || return 0
    for opt in status-left status-right status-bg status-style; do tmux set -u -t "$1" "$opt"; done
    for opt in window-status-format window-status-current-format; do
        for window in $windows; do tmux set -wu -t "$window" "$opt"; done
    done
}

focused() {
    tmux list-clients -t "$1" -F '#{client_flags}' | grep -q focused
}

case "$state" in
    in|out)
        # Focus events come in quick out/in pairs (sxhkd grabs the keyboard
        # for every Super shortcut, even one that moves nowhere), and each
        # starts its own copy of this script. Take turns per session, then
        # apply the focus tmux has now rather than the event that started us.
        # A closing window's session is already gone by the time its
        # focus-out arrives: nothing to do.
        tmux has-session -t "=$session" 2>/dev/null || exit 0
        lock="${XDG_RUNTIME_DIR:-/tmp}/tmux-focus-$(id -u)-$session.lock"
        exec 9>"$lock"
        flock 9
        tmux has-session -t "=$session" 2>/dev/null || exit 0
        if focused "$session"; then want=in; else want=out; fi
        [ "$(tmux show -t "$session" -v @focus_state 2>/dev/null)" = "$want" ] && exit 0
        if [ "$want" = in ]; then focus_in "$session"; else focus_out "$session"; fi
        tmux set -t "$session" @focus_state "$want"
        ;;
    sync)
        # The hooks only see focus changes; this catches terminals that were
        # already unfocused and rebuilds the copies from the current theme.
        tmux list-sessions -F '#{session_name}' | while IFS= read -r name; do
            focus_in "$name"
            if focused "$name"; then
                tmux set -t "$name" @focus_state in
            else
                focus_out "$name"
                tmux set -t "$name" @focus_state out
            fi
        done
        ;;
esac
