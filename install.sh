#!/bin/bash
set -e

START_TIME=$SECONDS
USER_HOME="$HOME"
export TERM="xterm-256color"

GREEN='\033[1;32m'
BLUE='\033[1;34m'
DIM='\033[2m'
RED='\033[1;31m'
NC='\033[0m'
BRIGHT_GREEN='\033[92;1m'
BRIGHT_RED='\033[0;91;1m'
BRIGHT_YELLOW='\033[0;93;1m'
BRIGHT_CYAN='\033[0;96;1m'

ok() { echo -e "${GREEN}✓${NC} ${1}"; }
fail() { echo -e "${RED}✗${NC} ${1}"; exit 1; }

banner() {
    echo -e "${GREEN}"
    echo ""
    echo ""
    echo -e "${BRIGHT_GREEN} ,,                                                      \e[0m"
    echo -e "${BRIGHT_GREEN}*MM                                                ${BRIGHT_CYAN}m.6*\" \e[0m"
    echo -e "${BRIGHT_GREEN} MM                                               ${BRIGHT_CYAN}m,M'    \e[0m"
    echo -e "${BRIGHT_GREEN} MM,dMMb.   .gP\"Ya \`7MMpMMMb. ${BRIGHT_RED}  pd*\"*b.  ${BRIGHT_YELLOW}M****** ${BRIGHT_CYAN}m,Mbmmm.\e[0m"
    echo -e "${BRIGHT_GREEN} MM    \`Mb ,M'   Yb  MM    MM  ${BRIGHT_RED}(O)   j8 ${BRIGHT_YELLOW}.M       ${BRIGHT_CYAN}m6M'  \`Mb.\e[0m"
    echo -e "${BRIGHT_GREEN} MM     M8 8M\"\"\"\"\"\"  MM    MM ${BRIGHT_RED}     ,;j9 ${BRIGHT_YELLOW}|bMMAg.  ${BRIGHT_CYAN}mMI     M8\e[0m"
    echo -e "${BRIGHT_GREEN} MM.   ,M9 YM.    ,  MM    MM   ${BRIGHT_RED},-='         ${BRIGHT_YELLOW}\`Mb ${BRIGHT_CYAN}mWM.   ,M9\e[0m"
    echo -e "${BRIGHT_GREEN} P^YbmdP'   \`Mbmmd'.JMML  JMML.${BRIGHT_RED}Ammmmmmm       ${BRIGHT_YELLOW}jM  ${BRIGHT_CYAN}mWMbmmd9 \e[0m"
    echo -e "${BRIGHT_GREEN}                                        ${BRIGHT_YELLOW}(O)  ,M9         \e[0m"
    echo -e "${BRIGHT_GREEN}                                         ${BRIGHT_YELLOW}6mmm9           \e[0m"
    echo ""
    echo ""
    echo -e "${NC}"
    echo -e "${BLUE}Base Environment Install${NC}"
    echo ""
}

# Prompt for sudo
sudo -v

# Bootstrap gum
if ! command -v gum &>/dev/null; then
    echo -ne "${BLUE}::${NC} Installing gum..."
    sudo apt update -qq > /dev/null 2>&1
    sudo apt install --yes -qq curl gnupg > /dev/null 2>&1
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
    sudo apt update -qq > /dev/null 2>&1
    sudo apt install --yes -qq gum > /dev/null 2>&1
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
    bspwm
    sxhkd
    firefox-esr
    fastfetch
)

# Update package lists (gum spinner)
gum spin --spinner line --title "Updating package lists" -- sudo apt update -qq
ok "Updated package lists"

# Install packages (gum spinner with progress bar, skip already installed)
install=()
for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        install+=("$pkg")
    fi
done
skipped=$(( ${#PACKAGES[@]} - ${#install[@]} ))
total=${#install[@]}
if [ "$total" -eq 0 ]; then
    ok "All ${#PACKAGES[@]} packages already installed"
else
    current=0
    for pkg in "${install[@]}"; do
        current=$((current + 1))
        pct=$((current * 100 / total))
        filled=$((pct / 5))
        empty=$((20 - filled))
        bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null))
        pad=$(printf '░%.0s' $(seq 1 $empty 2>/dev/null))
        if ! gum spin --spinner line --title "Installing packages [${current}/${total}] ${bar}${pad} ${pkg}" -- \
            sudo apt install --yes -qq "$pkg"; then
            fail "Failed to install ${pkg}"
        fi
    done
    ok "Installed ${total} packages (${skipped} already installed)"
fi

# Clone dotfiles (gum spinner)
if [ -d "$USER_HOME/dotfiles" ]; then
    ok "Dotfiles already present"
else
    gum spin --spinner line --title "Cloning dotfiles" -- \
        git clone -q -b nvim https://github.com/ben256dev/dotfiles.git "$USER_HOME/dotfiles"
    ok "Cloned dotfiles"
fi

# Link dotfiles
ln -sf "$USER_HOME/dotfiles/.bashrc"               "$USER_HOME/.bashrc"
ln -sf "$USER_HOME/dotfiles/.bash_aliases"         "$USER_HOME/.bash_aliases"
ln -sf "$USER_HOME/dotfiles/.gitconfig"            "$USER_HOME/.gitconfig"
ln -sf "$USER_HOME/dotfiles/.vimrc"                "$USER_HOME/.vimrc"
ln -sf "$USER_HOME/dotfiles/.tmux.conf"            "$USER_HOME/.tmux.conf"
ln -snf "$USER_HOME/dotfiles/.vim"                 "$USER_HOME/.vim"
ln -snf "$USER_HOME/dotfiles/.tmux"                "$USER_HOME/.tmux"
ln -snf "$USER_HOME/dotfiles/.kmonad"              "$USER_HOME/.kmonad"
mkdir -p "$USER_HOME/.config"
ln -snf "$USER_HOME/dotfiles/.config/nvim"         "$USER_HOME/.config/nvim"
mkdir -p "$USER_HOME/.ssh"
ln -sf "$USER_HOME/dotfiles/.ssh/config"           "$USER_HOME/.ssh/config"
mkdir -p "$USER_HOME/ghostty"
mkdir -p "$USER_HOME/ghostty/themes"
ln -sf "$USER_HOME/dotfiles/ghostty/themes/ben256" "$USER_HOME/ghostty/themes/ben256"
ln -snf "$USER_HOME/.config/ghostty"               "$USER_HOME/.config/ghostty"
ln -sf "$USER_HOME/dotfiles/.dircolors"            "$USER_HOME/.dircolors"
ok "Linked dotfiles"

# Set up ghostty
curl -sS https://debian.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/debian.griffo.io.gpg

echo "deb https://debian.griffo.io/apt $(lsb_release -sc 2>/dev/null) main" | sudo tee /etc/apt/sources.list.d/debian.griffo.io.list

sudo apt update

PACKAGES=(
    zig
    ghostty
    lazygit
    yazi
    eza
    uv
    fzf
    zoxide
    bun
    tigerbeetle
)

install
ok "Installed ghostty"

# Set up bspwm
mkdir -p "$USER_HOME/.config/bspwm"
cp /usr/share/doc/bspwm/examples/bspwmrc "$USER_HOME/.config/bspwm/bspwmrc"
chmod +x "$USER_HOME/.config/bspwm/bspwmrc"
sed -i 's/urxvt/ghostty/g; s/xterm/ghostty/g' "$USER_HOME/.config/bspwm/bspwmrc"
ok "Configured bspwm"

# Set up sxhkd
mkdir -p "$USER_HOME/.config/sxhkd"
cp /usr/share/doc/bspwm/examples/sxhkdrc "$USER_HOME/.config/sxhkd/sxhkdrc"
sed -i 's/urxvt/ghostty/g; s/xterm/ghostty/g' "$USER_HOME/.config/sxhkd/sxhkdrc"
ok "Configured sxhkd"

# Download wallpaper (gum spinner)
mkdir -p "$USER_HOME/Pictures"
gum spin --spinner line --title "Downloading wallpaper" -- \
    curl -sL "https://picsum.photos/1920/1080" -o "$USER_HOME/Pictures/wallpaper.jpg"
ok "Downloaded wallpaper"

# Create xinitrc
cat > "$USER_HOME/.xinitrc" << EOF
#!/bin/sh
export DISPLAY=:0
dbus-launch --exit-with-session &
xset s off; xset -dpms; xset s noblank
feh --bg-scale $USER_HOME/Pictures/wallpaper.jpg &
picom --backend xrender &
sxhkd &
exec bspwm
EOF
chmod +x "$USER_HOME/.xinitrc"
ok "Created ~/.xinitrc"

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
