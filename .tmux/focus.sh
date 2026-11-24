#!/bin/sh
# Unfocused terminals get a quieter status bar: just the session number and
# tabs as blue-grey text on the terminal's background (or Neovim's, when it's
# open in the active pane), no right side.
#
#   focus.sh        after the theme loads: give every status option a focused
#                   and an unfocused version, chosen by the session's
#                   @wm_focused
#   focus.sh sync   mark the session in the focused window (if any) focused
#                   and every other one unfocused, and redraw what changed
#
# Focus comes from bspwm, not from tmux's own focus events: those arrive via
# Ghostty and often lag by seconds, while bspwm knows at once. bspwmrc runs
# `focus.sh sync` on every focus change; tmux's focus hooks run it too, as a
# backup. Each Ghostty window is titled with its session's id (set-titles in
# .tmux.conf), which is how a window maps to a session.

if [ "${1:-}" = sync ]; then
    window=$(bspc query -N -n focused.window 2>/dev/null)
    title=${window:+$(xprop -id "$window" _NET_WM_NAME 2>/dev/null)}
    # _NET_WM_NAME(UTF8_STRING) = "tmux $3"  ->  $3
    focused_session=$(printf '%s' "$title" | sed -n 's/.*= "tmux \(\$[0-9]*\)"$/\1/p')
    tmux list-sessions -F '#{session_id} #{@wm_focused}' | while read -r session state; do
        want=0; [ "$session" = "$focused_session" ] && want=1
        [ "$state" = "$want" ] && continue
        # A user option change doesn't redraw by itself.
        tmux set -t "$session" @wm_focused "$want"
        tmux list-clients -t "$session" -F '#{client_name}' |
            while IFS= read -r client; do tmux refresh-client -S -t "$client"; done
    done
    exit 0
fi

# The two versions are kept in @focused_* / @unfocused_* options, and each
# status option picks one.
focused='#{==:#{@wm_focused},1}'

# A reload reruns the theme, which overwrites the options again; without a
# reload they already point at the copies, so leave them.
case "$(tmux show -gv status-left)" in *@focused_*) exit 0 ;; esac

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

# Behind the quiet bar: Neovim's background when it's open in the active pane
# (it sets @editor_bg), otherwise the terminal's own.
bg='#{?@editor_bg,#{@editor_bg},default}'

# Text only: every background becomes the terminal's, and the solid powerline
# arrows (which only draw block edges) become spaces, so the text sits in the
# same columns as when focused. The thin separators stay.
text_only() {
    # (Through the environment: in Perl's own code, @editor_bg would be an
    # empty array.)
    bg=$bg perl -pe 's/bg=#[0-9a-f]{6}/bg=$ENV{bg}/gi; s/\xee\x82[\xb0\xb2]/ /g'
}

# The theme colours the bar with status-bg/status-fg, which win over
# status-style; move them into status-style so it can choose.
bar_bg=$(tmux show -gv status-bg) bar_fg=$(tmux show -gv status-fg)
tmux set -g @focused_status-style "bg=$bar_bg,fg=$bar_fg"
tmux set -g @unfocused_status-style "bg=$bg,fg=$(printf '%s' "$bar_fg" | grey)"

# The session badge's dark text would vanish on the terminal background, so
# it takes the bar's text colour.
left=$(tmux show -gv status-left)
tmux set -g @focused_status-left "$left"
tmux set -g @unfocused_status-left "$(printf '%s' "$left" | grey | sed "s/fg=$bar_bg/fg=$bar_fg/" | text_only)"

# The focused bar starts its right side with the cheatsheet hint
# (@cheatsheet_hint, set in .tmux.conf), in the theme's text colour.
tmux set -g @focused_status-right "#[fg=$bar_fg,bg=$bar_bg]#{@cheatsheet_hint}   $(tmux show -gv status-right)"
tmux set -g @unfocused_status-right ''

# A tab whose pane is in copy mode has its number and name in copy mode's
# cursor colour (@copy_mode_colour, .tmux.conf), focused or not.
copy_mode='#{?#{==:#{pane_mode},copy-mode},#[fg=#{@copy_mode_colour}],}'
for opt in window-status-format window-status-current-format; do
    value=$(tmux show -gwv "$opt" | copy_mode=$copy_mode perl -pe 's/(?=#I\b)/$ENV{copy_mode}/')
    tmux set -g "@focused_$opt" "$value"
    tmux set -g "@unfocused_$opt" "$(printf '%s' "$value" | grey | text_only)"
done

# Switch over in one tmux call, so the bar never shows a half-done mix (with
# status-bg cleared but status-style not yet set, tmux's default green bar
# would flash up).
pick() { printf '#{?%s,#{E:@focused_%s},#{E:@unfocused_%s}}' "$focused" "$1" "$1"; }
tmux set -g status-bg default \; set -g status-fg default \; \
    set -g status-style "$(pick status-style)" \; \
    set -g status-left "$(pick status-left)" \; \
    set -g status-right "$(pick status-right)" \; \
    set -gw window-status-format "$(pick window-status-format)" \; \
    set -gw window-status-current-format "$(pick window-status-current-format)"

# The script this replaced gave unfocused sessions their own copies of these
# options, which would hide the global ones; clear any that are left.
tmux list-sessions -F '#{session_name}' | while IFS= read -r session; do
    for opt in status-left status-right status-bg status-style @focus_state; do
        tmux set -u -t "$session" "$opt"
    done
    tmux list-windows -t "$session" -F '#{window_id}' | while IFS= read -r window; do
        tmux set -wu -t "$window" window-status-format \; set -wu -t "$window" window-status-current-format
    done
done
