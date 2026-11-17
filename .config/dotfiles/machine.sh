# Per-machine settings. Sourced by .xinitrc, install.sh, .kmonad/setup.sh and
# the Firefox launcher. Sets nothing by default; settings come from, in order:
#   machines/<hostname>.sh         tracked, applies only on that machine
#   ~/.config/dotfiles/local.sh    untracked, overrides the above
# Recognised settings: KMONAD_DEVICE, FIREFOX_GTK_PREFIX, machine_display_setup().
_dotfiles_conf="${DOTFILES_DIR:+$DOTFILES_DIR/.config/dotfiles}"
: "${_dotfiles_conf:=$HOME/.config/dotfiles}"
_dotfiles_host="$(uname -n)"
for _dotfiles_file in "$_dotfiles_conf/machines/${_dotfiles_host%%.*}.sh" "$HOME/.config/dotfiles/local.sh"; do
    # shellcheck disable=SC1090
    [ ! -r "$_dotfiles_file" ] || . "$_dotfiles_file"
done
unset _dotfiles_conf _dotfiles_host _dotfiles_file
