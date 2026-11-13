#!/bin/bash
set -euo pipefail

# Config-only operations never request sudo or touch packages/services.
case "${1:-}" in
    --apply|--dry-run)
        exec "$(dirname "${BASH_SOURCE[0]}")/scripts/apply" "$1"
        ;;
    --migrate) MIGRATE=1 ;;
    '') MIGRATE=0 ;;
    *) echo 'Usage: install.sh [--migrate|--apply|--dry-run]' >&2; exit 2 ;;
esac

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

umask 077
INSTALL_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/logs"
mkdir -p "$INSTALL_LOG_DIR"
INSTALL_LOG="$INSTALL_LOG_DIR/install-$(date +%Y%m%d-%H%M%S)-$$.log"
touch "$INSTALL_LOG"

spin_logged() {
    local title="$1"
    shift
    env -u NO_COLOR gum spin --spinner.foreground=212 --spinner line --title "$title" -- \
        "$DOTFILES_DIR/scripts/run-logged" "$INSTALL_LOG" "$@"
}

# Prompt for sudo once, then keep it fresh for the whole run.
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true' EXIT

# Bootstrap what this script itself needs. Errors stay visible.
echo -ne "${BLUE}::${NC} Preparing apt..."
"${APT[@]}" update >> "$INSTALL_LOG" 2>&1
"${APT[@]}" install curl git gnupg ca-certificates >> "$INSTALL_LOG" 2>&1
sudo mkdir -p /etc/apt/keyrings
if ! command -v gum &>/dev/null; then
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
    "${APT[@]}" update >> "$INSTALL_LOG" 2>&1
    "${APT[@]}" install gum >> "$INSTALL_LOG" 2>&1
fi

# Clear screen and reprint clean
clear
banner
ok "Updated package lists"

install_packages() {
    local pkg candidate installed
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
        if ! dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null | grep -qx installed; then
            to_install+=("$pkg")
        elif [ "${PACKAGE_SOURCE:-apt}" = github ]; then
            candidate=$(apt-cache policy "$pkg" | sed -n 's/^  Candidate: //p')
            installed=$(dpkg-query -W -f='${Version}' "$pkg")
            if dpkg --compare-versions "$installed" lt "$candidate"; then
                to_install+=("$pkg")
            fi
        fi
    done

    local total=${#to_install[@]}
    local skipped=$(( ${#resolved[@]} - total ))
    if [ "$total" -eq 0 ]; then
        ok "All ${#resolved[@]} packages already installed"
        return
    fi

    local current=0 failed=0 filled bar pad
    local -a install_command
    for pkg in "${to_install[@]}"; do
        current=$((current + 1))
        filled=$((current * 20 / total))
        printf -v bar '%*s' "$filled" ''
        printf -v pad '%*s' "$((20 - filled))" ''
        bar=${bar// /█}
        pad=${pad// /░}
        if [ "${PACKAGE_SOURCE:-apt}" = github ] && [ "$pkg" != diff-so-fancy ] && [ "$pkg" != aha ]; then
            install_command=(python3 "$DOTFILES_DIR/scripts/install-release-deb" "$pkg")
        else
            install_command=("${APT[@]}" --no-remove install "$pkg")
        fi
        if ! spin_logged "Installing packages [${current}/${total}] ${bar}${pad} ${pkg}" \
            "${install_command[@]}"; then
            warn "Failed to install ${pkg}"
            failed=$((failed + 1))
        fi
    done
    ok "Installed $((total - failed))/${total} packages (${skipped} already installed)"
}

PACKAGES=(
    python3
    adwaita-icon-theme
    tmux
    xorg
    x11-utils
    x11-xserver-utils
    xinit
    xclip
    feh
    imagemagick
    picom
    suckless-tools
    dbus-x11
    fzf
    fd-find
    bspwm
    sxhkd
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
    env -u NO_COLOR gum spin --spinner.foreground=212 --spinner line --show-error --title "Cloning dotfiles" -- \
        git clone -q -b main https://github.com/ben256dev/dotfiles.git "$DOTFILES_DIR"
    ok "Cloned dotfiles into $DOTFILES_DIR"
fi

# Apply only after packages are installed (below).


# Set up ghostty repo (also provides zig, lazygit, yazi, eza, uv, bun, ...)
DIST_CODENAME="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
[ -n "$DIST_CODENAME" ] || fail "Could not detect distro codename for Ghostty repo."
GRIFFO_KEY=/etc/apt/keyrings/debian.griffo.io.gpg
curl -fsSL https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | sudo gpg --dearmor --yes -o "$GRIFFO_KEY"
# Older versions of this script trusted the key for every repo; scope it instead.
sudo rm -f /etc/apt/trusted.gpg.d/debian.griffo.io.gpg
echo "deb [signed-by=$GRIFFO_KEY] https://debian.griffo.io/apt ${DIST_CODENAME} main" | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list > /dev/null
spin_logged "Updating package lists" "${APT[@]}" update
ok "Added ghostty repo"

# Public GitHub assets have the same SHA256 as the signed apt index, and do
# not require the mirror's new subscription. Keep downloads quiet and verified.
PACKAGE_SOURCE=github install_packages fastfetch neovim zig ghostty lazygit yazi eza uv diff-so-fancy aha zoxide bun tigerbeetle

# Leave only the free mirror configured for future apt updates/upgrades.
echo "deb [signed-by=$GRIFFO_KEY] https://deb-free.griffo.io/apt ${DIST_CODENAME} main" | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list > /dev/null
spin_logged "Refreshing free package source" "${APT[@]}" update

if command -v gdformat >/dev/null 2>&1; then
    ok "gdtoolkit is already installed"
elif ! command -v uv >/dev/null 2>&1; then
    warn "uv is not installed; skipping gdtoolkit"
elif spin_logged "Installing gdtoolkit" uv tool install gdtoolkit; then
    ok "Installed gdtoolkit"
else
    warn "Failed to install gdtoolkit; continuing"
fi

WALLPAPER="$HOME/Pictures/wallpaper.jpg"
if [ -f "$WALLPAPER" ]; then
    ok "Wallpaper already downloaded"
else
    mkdir -p "$(dirname "$WALLPAPER")"
    if env -u NO_COLOR gum spin --spinner.foreground=212 --spinner line --title "Downloading wallpaper" -- \
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
if [ "$MIGRATE" -eq 0 ] && [ -f /etc/ssh/sshd_config ]; then
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

if [ -r "$DOTFILES_DIR/.config/dotfiles/machine.sh" ]; then
    # shellcheck disable=SC1091
    . "$DOTFILES_DIR/.config/dotfiles/machine.sh"
fi
if [ -n "${FIREFOX_GTK_PREFIX:-}" ]; then
    spin_logged "Building GTK" "$DOTFILES_DIR/scripts/setup-gtk3"
fi

# Fail visibly rather than replacing working hotkeys with missing programs.
for required in ghostty rofi bspc sxhkd python3 nvim tmux dbus-launch feh picom; do
    need_cmd "$required"
done
"$DOTFILES_DIR/scripts/apply" --apply >/dev/null
ok "Linked dotfiles"
if [ -n "${FIREFOX_GTK_PREFIX:-}" ]; then
    python3 "$DOTFILES_DIR/scripts/firefox-launcher"
fi

# Keyboard remapping (Colemak-DH) as a boot-time service. Last, so the layout
# only changes once everything else is done.
if spin_logged "Setting up kmonad" "$DOTFILES_DIR/.kmonad/setup.sh"; then
    ok "Set up kmonad"
else
    fail "kmonad setup failed"
fi

elapsed=$(( SECONDS - START_TIME ))
mins=$(( elapsed / 60 ))
secs=$(( elapsed % 60 ))
echo -e "${GREEN}Install finished${NC} in ${mins}m${secs}s"
echo ""
echo -e "Run ${BLUE}startx${NC} to launch the desktop."
