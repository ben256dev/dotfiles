#!/bin/bash
set -euo pipefail

START_TIME=$SECONDS
export TERM="xterm-256color"

GREEN='\033[1;32m'
BLUE='\033[1;34m'
RED='\033[1;31m'
NC='\033[0m'
BRIGHT_RED='\033[0;91;1m'
BRIGHT_YELLOW='\033[0;93;1m'
CYAN='\033[0;36;1m'
BOLD_WHITE='\033[1;97m'

# Non-interactive apt that waits for the dpkg lock (a fresh boot often runs
# apt-daily in the background) instead of failing.
APT=(sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y -o DPkg::Lock::Timeout=300)

ok() { echo -e "${GREEN}✓${NC} ${1}"; }
warn() { echo -e "${BRIGHT_YELLOW}!${NC} ${1}"; }
fail() { echo -e "${RED}✗${NC} ${1}"; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"; }
pkg_exists() { apt-cache show "$1" >/dev/null 2>&1; }

banner() {
    echo -e "${GREEN}"
    echo ""
    echo ""
    echo -e "           ${BRIGHT_RED}        V█n        "
    echo -e "           ${BRIGHT_RED}      V█████N      "
    echo -e "           ${BRIGHT_RED}    V█████████N    "
    echo -e "           ${BRIGHT_RED}  V█████████████N       ${BOLD_WHITE} ,,                                                      \e[0m"
    echo -e "           ${BRIGHT_RED}c█████████████████n     ${BOLD_WHITE}*MM                                                ${CYAN}m.6*\" \e[0m"
    echo -e " ${BRIGHT_YELLOW}█████████${BRIGHT_RED}n█████████████████c      ${BOLD_WHITE} MM                                               ${CYAN}m,M'    \e[0m"
    echo -e " ${BRIGHT_YELLOW}█████████${BRIGHT_RED}  N█████████████V        ${BOLD_WHITE} MM,dMMb.   .gP\"Ya \`7MMpMMMb. ${BRIGHT_RED}  pd*\"*b.  ${BRIGHT_YELLOW}M****** ${CYAN}m,Mbmmm.\e[0m"
    echo -e " ${BRIGHT_YELLOW}█████████${BRIGHT_RED}    N█████████V          ${BOLD_WHITE} MM    \`Mb ,M'   Yb  MM    MM  ${BRIGHT_RED}(O)   j8 ${BRIGHT_YELLOW}.M       ${CYAN}m6M'  \`Mb.\e[0m"
    echo -e " ${BRIGHT_YELLOW}█████████${BRIGHT_RED}      N█████V            ${BOLD_WHITE} MM     M8 8M\"\"\"\"\"\"  MM    MM ${BRIGHT_RED}     ,;j9 ${BRIGHT_YELLOW}|bMMAg.  ${CYAN}mMI     M8\e[0m"
    echo -e " ${BRIGHT_YELLOW}█████████${BRIGHT_RED}        n█V              ${BOLD_WHITE} MM.   ,M9 YM.    ,  MM    MM   ${BRIGHT_RED},-='         ${BRIGHT_YELLOW}\`Mb ${CYAN}mWM.   ,M9\e[0m"
    echo -e "          ${CYAN}█████████                 ${BOLD_WHITE}P^YbmdP'   \`Mbmmd'.JMML  JMML.${BRIGHT_RED}Ammmmmmm       ${BRIGHT_YELLOW}jM  ${CYAN}mWMbmmd9 \e[0m"
    echo -e "          ${CYAN}█████████                                                        ${BRIGHT_YELLOW}(O)  ,M9         \e[0m"
    echo -e "          ${CYAN}█████████                                                         ${BRIGHT_YELLOW}6mmm9           \e[0m"
    echo -e "          ${CYAN}█████████     "
    echo -e "          ${CYAN}█████████     "
    echo ""
    echo ""
    echo -e "${NC}"
    echo -e "${BLUE}Base Environment Install${NC}"
    echo ""
}

if [ "$(id -u)" -eq 0 ]; then
    fail "Run this script as your normal user, not root."
fi

need_cmd sudo
need_cmd apt-get
need_cmd dpkg

# Where the repo lives: $DOTFILES_DIR if set, else next to this script, else
# ~/dotfiles (when piped from the web there is no script path).
if [ -n "${DOTFILES_DIR:-}" ]; then
    [ -f "$DOTFILES_DIR/install.sh" ] || fail "DOTFILES_DIR is invalid: $DOTFILES_DIR"
elif [ -f "${BASH_SOURCE[0]:-}" ]; then
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    DOTFILES_DIR="$HOME/dotfiles"
fi

# Prompt for sudo once, then keep it fresh for the whole run.
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true' EXIT

# Bootstrap what this script itself needs. Errors stay visible.
echo -ne "${BLUE}::${NC} Preparing apt..."
"${APT[@]}" update >/dev/null
"${APT[@]}" install curl git gnupg ca-certificates >/dev/null
sudo mkdir -p /etc/apt/keyrings
if ! command -v gum &>/dev/null; then
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
    "${APT[@]}" update >/dev/null
    "${APT[@]}" install gum >/dev/null
fi

# Clear screen and reprint clean
clear
banner
ok "Updated package lists"

install_packages() {
    local pkg
    local resolved=()
    local to_install=()

    for pkg in "$@"; do
        if pkg_exists "$pkg"; then
            resolved+=("$pkg")
        else
            warn "Skipping unavailable package: $pkg"
        fi
    done

    if [ "${#resolved[@]}" -eq 0 ]; then
        warn "No installable packages in this group"
        return
    fi

    for pkg in "${resolved[@]}"; do
        dpkg -s "$pkg" &>/dev/null || to_install+=("$pkg")
    done

    local total=${#to_install[@]}
    local skipped=$(( ${#resolved[@]} - total ))
    if [ "$total" -eq 0 ]; then
        ok "All ${#resolved[@]} packages already installed"
        return
    fi

    local current=0 failed=0 filled bar pad
    for pkg in "${to_install[@]}"; do
        current=$((current + 1))
        filled=$((current * 20 / total))
        printf -v bar '%*s' "$filled" ''
        printf -v pad '%*s' "$((20 - filled))" ''
        bar=${bar// /█}
        pad=${pad// /░}
        if ! gum spin --spinner line --show-error --title "Installing packages [${current}/${total}] ${bar}${pad} ${pkg}" -- \
            "${APT[@]}" install "$pkg"; then
            warn "Failed to install ${pkg}; continuing"
            failed=$((failed + 1))
        fi
    done
    ok "Installed $((total - failed))/${total} packages (${skipped} already installed)"
}

PACKAGES=(
    neovim
    tmux
    xorg
    x11-utils
    x11-xserver-utils
    xinit
    xclip
    feh
    picom
    suckless-tools
    dbus-x11
    fzf
    fd-find
    bspwm
    sxhkd
    fastfetch
    tree
    rofi
    papirus-icon-theme
    fonts-jetbrains-mono
    git-lfs
)
if pkg_exists firefox-esr; then
    PACKAGES+=(firefox-esr)
else
    PACKAGES+=(firefox)
fi

install_packages "${PACKAGES[@]}"

# When piped from the web, fetch the repo so there is something to link to.
if [ ! -f "$DOTFILES_DIR/install.sh" ]; then
    gum spin --spinner line --show-error --title "Cloning dotfiles" -- \
        git clone -q -b main https://github.com/ben256dev/dotfiles.git "$DOTFILES_DIR"
    ok "Cloned dotfiles into $DOTFILES_DIR"
fi

# Symlink a repo path to the same path under $HOME. Anything already there that
# isn't a symlink is moved aside to <path>.bak.<timestamp>, never overwritten.
link() {
    local src="$DOTFILES_DIR/$1"
    local dst="$HOME/$1"

    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"
        warn "Moved existing ~/$1 aside to ~/$1.bak.*"
    fi
    ln -sfn "$src" "$dst"
}

mkdir -p -m 700 "$HOME/.ssh"
for path in \
    .bashrc .bash_aliases .gitconfig .xinitrc .ssh/config \
    .tmux.conf .tmux/copy.sh .tmux/battery.sh .kmonad .local/bin/v \
    .config/nvim .config/ghostty .config/rofi \
    .config/bspwm .config/sxhkd .config/picom
do
    link "$path"
done

# Remove dangling links to files this repo no longer ships.
for path in .vimrc .vim .dircolors .config/shell/v.sh; do
    if [ -L "$HOME/$path" ] && [ ! -e "$HOME/$path" ]; then
        rm "$HOME/$path"
    fi
done
ok "Linked dotfiles"

# Set up ghostty repo (also provides zig, lazygit, yazi, eza, uv, bun, ...)
DIST_CODENAME="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
[ -n "$DIST_CODENAME" ] || fail "Could not detect distro codename for Ghostty repo."
GRIFFO_KEY=/etc/apt/keyrings/debian.griffo.io.gpg
curl -fsSL https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | sudo gpg --dearmor --yes -o "$GRIFFO_KEY"
# Older versions of this script trusted the key for every repo; scope it instead.
sudo rm -f /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
echo "deb [signed-by=$GRIFFO_KEY] https://debian.griffo.io/apt ${DIST_CODENAME} main" | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list > /dev/null
gum spin --spinner line --show-error --title "Updating package lists" -- "${APT[@]}" update
ok "Added ghostty repo"

install_packages zig ghostty lazygit yazi eza uv diff-so-fancy aha zoxide bun tigerbeetle

if command -v gdformat >/dev/null 2>&1; then
    ok "gdtoolkit is already installed"
elif ! command -v uv >/dev/null 2>&1; then
    warn "uv is not installed; skipping gdtoolkit"
elif gum spin --spinner line --show-error --title "Installing gdtoolkit" -- uv tool install gdtoolkit; then
    ok "Installed gdtoolkit"
else
    warn "Failed to install gdtoolkit; continuing"
fi

WALLPAPER="$HOME/Pictures/wallpaper.jpg"
if [ -f "$WALLPAPER" ]; then
    ok "Wallpaper already downloaded"
else
    mkdir -p "$(dirname "$WALLPAPER")"
    if gum spin --spinner line --title "Downloading wallpaper" -- \
        curl -fsSL "https://unsplash.com/photos/SowPhAbCbcs/download?force=true" -o "$WALLPAPER.part"; then
        mv "$WALLPAPER.part" "$WALLPAPER"
        ok "Downloaded wallpaper"
    else
        rm -f "$WALLPAPER.part"
        warn "Failed to download wallpaper; continuing"
    fi
fi

# Quiet SSH logins: no motd, no "Last login" line. A drop-in file leaves
# Debian's sshd_config untouched, so package upgrades don't prompt about it.
if [ -f /etc/ssh/sshd_config ]; then
    sudo chmod -x /etc/update-motd.d/* 2>/dev/null || true
    sudo truncate -s 0 /etc/motd
    sudo mkdir -p /etc/ssh/sshd_config.d
    printf 'PrintMotd no\nPrintLastLog no\n' | sudo tee /etc/ssh/sshd_config.d/10-quiet-login.conf > /dev/null
    if sudo sshd -t; then
        sudo systemctl restart ssh
        ok "Cleaned up SSH logins"
    else
        warn "sshd config test failed; not restarting ssh"
    fi
fi

# Keyboard remapping (Colemak-DH) as a boot-time service. Last, so the layout
# only changes once everything else is done.
if gum spin --spinner line --show-error --title "Setting up kmonad" -- "$DOTFILES_DIR/.kmonad/setup.sh"; then
    ok "Set up kmonad: the keyboard is now Colemak-DH (Right Alt + Left Win toggles QWERTY)"
else
    warn "kmonad isn't running; see the message above and .kmonad/README.md"
fi

elapsed=$(( SECONDS - START_TIME ))
mins=$(( elapsed / 60 ))
secs=$(( elapsed % 60 ))
echo -e "${GREEN}Install finished${NC} in ${mins}m${secs}s"
echo ""
echo -e "Run ${BLUE}startx${NC} to launch the desktop."
