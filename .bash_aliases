alias gcu311="buc -s gc_github_user=benjaminblodgett311"
alias gcu256="buc -s gc_github_user=ben256dev"
alias cwd="cd ~/ben256"
alias cwm="cd /var/www/ben256"
alias cwc="cd /etc/nginx/sites-available"
alias c="clear"
alias cl="c;l"
alias tt="toggle_touchpad"
alias cdl="source change_directory_and_list"
alias cppc="cppcheck --enable=all --suppress=missingIncludeSystem"
alias cr="claude --resume"
alias clr="claude --continue --dangerously-skip-permissions"
alias bb="ssh benjamin@ssh.shthub.org"
export ONYX="benjaminblodgett311@onyx.boisestate.edu"
alias onyx="ssh $ONYX"
alias godot="$HOME/.local/bin/godot4 >/dev/null 2>&1"
alias cdr="codex resume --last --yolo --no-daemon"

# Clipboard: `cmd | copy`, `paste`. Wayland or X11, whichever is running
# (functions, so the choice is made when they run, not when the shell starts).
copy() {
    if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null; then
        wl-copy "$@"
    else
        xclip -selection clipboard -in "$@"
    fi
}
paste() {
    if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-paste >/dev/null; then
        wl-paste "$@"
    else
        xclip -selection clipboard -out "$@"
    fi
}
