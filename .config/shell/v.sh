# Prefer executable v script when present
if [ -x "$HOME/.local/bin/v" ]; then
  unalias v >/dev/null 2>&1 || true
  unset -f v >/dev/null 2>&1 || true
  v() {
    "$HOME/.local/bin/v" "$@"
  }
fi
