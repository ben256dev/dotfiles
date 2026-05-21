# Prefer executable v script when present
if [ -x "$HOME/.local/bin/v" ]; then
  v() {
    "$HOME/.local/bin/v" "$@"
  }
fi
