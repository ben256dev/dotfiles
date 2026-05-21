#!/bin/bash
set -euo pipefail

START_TIME=$SECONDS
USER_HOME="$HOME"
export TERM="xterm-256color"
SCRIPT_SOURCE="${BASH_SOURCE[0]-}"
if [ -n "$SCRIPT_SOURCE" ] && [ "$SCRIPT_SOURCE" != "bash" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
else
    # When piped to bash (`curl ... | bash`), no script path is available.
    SCRIPT_DIR="$PWD"
fi
DOTFILES_DIR_INPUT="${DOTFILES_DIR-}"
DOTFILES_DIR="${DOTFILES_DIR_INPUT:-$SCRIPT_DIR}"

GREEN='\033[1;32m'
BLUE='\033[1;34m'
DIM='\033[2m'
RED='\033[1;31m'
NC='\033[0m'
BRIGHT_GREEN='\033[92;1m'
BRIGHT_RED='\033[0;91;1m'
BRIGHT_YELLOW='\033[0;93;1m'
BRIGHT_CYAN='\033[0;96;1m'
CYAN='\033[0;36;1m'
BOLD_WHITE='\033[1;97m'

ok() { echo -e "${GREEN}✓${NC} ${1}"; }
warn() { echo -e "${BRIGHT_YELLOW}!${NC} ${1}"; }
fail() { echo -e "${RED}✗${NC} ${1}"; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"; }
apt_quiet_install() { sudo DEBIAN_FRONTEND=noninteractive apt install --yes -qq "$@"; }
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
need_cmd apt
need_cmd dpkg
need_cmd curl
need_cmd git

if [ ! -d "$DOTFILES_DIR" ] || [ ! -f "$DOTFILES_DIR/install.sh" ]; then
    if [ -n "$DOTFILES_DIR_INPUT" ]; then
        fail "DOTFILES_DIR is invalid: $DOTFILES_DIR"
    fi
    DOTFILES_DIR="$USER_HOME/dotfiles"
fi

# Prompt for sudo
sudo -v

# Bootstrap gum
if ! command -v gum &>/dev/null; then
    echo -ne "${BLUE}::${NC} Installing gum..."
    sudo apt update -qq > /dev/null 2>&1
    apt_quiet_install curl gnupg ca-certificates > /dev/null 2>&1
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
    sudo apt update -qq > /dev/null 2>&1
    apt_quiet_install gum > /dev/null 2>&1
fi

# Clear screen and reprint clean
clear
banner

PACKAGES=(
    git
    curl
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
    __FIREFOX_PKG__
    fastfetch
    tree
    rofi
    papirus-icon-theme
)

if pkg_exists firefox-esr; then
    FIREFOX_PKG="firefox-esr"
elif pkg_exists firefox; then
    FIREFOX_PKG="firefox"
else
    FIREFOX_PKG=""
fi

if [ -n "$FIREFOX_PKG" ]; then
    for i in "${!PACKAGES[@]}"; do
        if [ "${PACKAGES[$i]}" = "__FIREFOX_PKG__" ]; then
            PACKAGES[$i]="$FIREFOX_PKG"
            break
        fi
    done
else
    filtered=()
    for pkg in "${PACKAGES[@]}"; do
        [ "$pkg" = "__FIREFOX_PKG__" ] && continue
        filtered+=("$pkg")
    done
    PACKAGES=("${filtered[@]}")
    warn "Neither firefox-esr nor firefox is available in apt; skipping browser install"
fi

# Update package lists (gum spinner)
gum spin --spinner line --title "Updating package lists" -- sudo apt update -qq
ok "Updated package lists"

install_packages() {
    local pkgs=("$@")
    local resolved=()
    local to_install=()

    for pkg in "${pkgs[@]}"; do
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
        if ! dpkg -s "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done
    local skipped=$(( ${#resolved[@]} - ${#to_install[@]} ))
    local total=${#to_install[@]}
    if [ "$total" -eq 0 ]; then
        ok "All ${#resolved[@]} packages already installed"
    else
        local current=0
        for pkg in "${to_install[@]}"; do
            current=$((current + 1))
            pct=$((current * 100 / total))
            filled=$((pct / 5))
            empty=$((20 - filled))
            bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null))
            pad=$(printf '░%.0s' $(seq 1 $empty 2>/dev/null))
            if ! gum spin --spinner line --title "Installing packages [${current}/${total}] ${bar}${pad} ${pkg}" -- \
                sudo DEBIAN_FRONTEND=noninteractive apt install --yes -qq "$pkg"; then
                if [ "$pkg" = "firefox-esr" ] && pkg_exists firefox; then
                    warn "Failed to install firefox-esr; trying firefox"
                    if ! gum spin --spinner line --title "Installing fallback package firefox" -- \
                        sudo DEBIAN_FRONTEND=noninteractive apt install --yes -qq firefox; then
                        warn "Failed to install firefox fallback; continuing"
                    else
                        ok "Installed firefox fallback"
                    fi
                else
                    warn "Failed to install ${pkg}; continuing"
                fi
            fi
        done
        ok "Installed ${total} packages (${skipped} already installed)"
    fi
}

install_packages "${PACKAGES[@]}"

# If running from a piped script, ensure we have the repo locally for symlinks.
if [ ! -d "$DOTFILES_DIR" ] || [ ! -f "$DOTFILES_DIR/install.sh" ]; then
    gum spin --spinner line --title "Cloning dotfiles" -- \
        git clone -q -b main https://github.com/ben256dev/dotfiles.git "$DOTFILES_DIR"
    ok "Cloned dotfiles into $DOTFILES_DIR"
fi

# Keep sudo fresh while running long installs
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true' EXIT

# Link dotfiles
ln -sf "$DOTFILES_DIR/.bashrc"                "$USER_HOME/.bashrc"
ln -sf "$DOTFILES_DIR/.bash_aliases"          "$USER_HOME/.bash_aliases"
ln -sf "$DOTFILES_DIR/.gitconfig"             "$USER_HOME/.gitconfig"
ln -sf "$DOTFILES_DIR/.vimrc"                 "$USER_HOME/.vimrc"
#ln -sf "$DOTFILES_DIR/.tmux.conf"             "$USER_HOME/.tmux.conf"
#ln -snf "$DOTFILES_DIR/.vim"                  "$USER_HOME/.vim"
#ln -snf "$DOTFILES_DIR/.tmux"                 "$USER_HOME/.tmux"
ln -snf "$DOTFILES_DIR/.kmonad"               "$USER_HOME/.kmonad"
mkdir -p "$USER_HOME/.config"
mkdir -p "$USER_HOME/.config/shell"
mkdir -p "$USER_HOME/.local/bin"
ln -snf "$DOTFILES_DIR/.config/nvim"          "$USER_HOME/.config/nvim"
ln -sf "$DOTFILES_DIR/.config/shell/v.sh"     "$USER_HOME/.config/shell/v.sh"
ln -sf "$DOTFILES_DIR/.local/bin/v"           "$USER_HOME/.local/bin/v"
chmod +x "$DOTFILES_DIR/.local/bin/v"
mkdir -p "$USER_HOME/.ssh"
ln -sf "$DOTFILES_DIR/.ssh/config"            "$USER_HOME/.ssh/config"
ln -snf "$DOTFILES_DIR/.config/ghostty"       "$USER_HOME/.config/ghostty"
ln -snf "$DOTFILES_DIR/.config/rofi"          "$USER_HOME/.config/rofi"
ln -sf "$DOTFILES_DIR/.dircolors"             "$USER_HOME/.dircolors"
ln -sf "$DOTFILES_DIR/.xinitrc"               "$USER_HOME/.xinitrc"
ok "Linked dotfiles"

# Set up ghostty repo
if command -v lsb_release >/dev/null 2>&1; then
    DIST_CODENAME="$(lsb_release -sc)"
elif [ -r /etc/os-release ]; then
    DIST_CODENAME="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
else
    DIST_CODENAME=""
fi

[ -n "${DIST_CODENAME}" ] || fail "Could not detect distro codename for Ghostty repo."
curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg > /dev/null 2>&1
echo "deb https://debian.griffo.io/apt ${DIST_CODENAME} main" | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list > /dev/null
gum spin --spinner line --title "Updating package lists" -- sudo apt update -qq
ok "Added ghostty repo"

PACKAGES=(
    zig
    ghostty
    lazygit
    yazi
    eza
    uv
    fzf
    diff-so-fancy
    zoxide
    bun
    tigerbeetle
)

install_packages "${PACKAGES[@]}"

# Link bspwm, sxhkd, picom configs
ln -snf "$DOTFILES_DIR/.config/bspwm"          "$USER_HOME/.config/bspwm"
chmod +x "$DOTFILES_DIR/.config/bspwm/bspwmrc"
ln -snf "$DOTFILES_DIR/.config/sxhkd"          "$USER_HOME/.config/sxhkd"
ln -snf "$DOTFILES_DIR/.config/picom"          "$USER_HOME/.config/picom"
ok "Configured bspwm, sxhkd, picom"

# Download wallpaper (gum spinner)
mkdir -p "$USER_HOME/Pictures"
gum spin --spinner line --title "Downloading wallpaper" -- \
    curl -sL "https://unsplash.com/photos/SowPhAbCbcs/download?force=true" -o "$USER_HOME/Pictures/wallpaper.jpg"
ok "Downloaded wallpaper"

# Clean up SSH logins
if [ -f /etc/ssh/sshd_config ]; then
    sudo chmod -x /etc/update-motd.d/* 2>/dev/null || true
    sudo truncate -s 0 /etc/motd
    sudo sed -i 's/^#\?PrintMotd.*/PrintMotd no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#\?PrintLastLog.*/PrintLastLog no/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
    ok "Cleaned up SSH logins"
fi

elapsed=$(( SECONDS - START_TIME ))
mins=$(( elapsed / 60 ))
secs=$(( elapsed % 60 ))
echo -e "${GREEN}Install finished${NC} in ${mins}m${secs}s"
echo ""
echo -e "Run ${BLUE}startx${NC} to launch the desktop."
