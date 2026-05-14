#!/usr/bin/env bash
# omniscan installer — installs omniscan (Python) + PhoneInfoga (Go binary)
# Usage: curl -fsSL https://raw.githubusercontent.com/HubDamian95/omniscan/master/install.sh | bash
set -euo pipefail

PHONEINFOGA_REPO="sundowndev/phoneinfoga"
SYSTEM_BIN="/usr/local/bin"

log()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
ok()   { printf '\e[1;32m ok\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33mwarn:\e[0m %s\n' "$*" >&2; }
err()  { printf '\e[1;31merror:\e[0m %s\n' "$*" >&2; exit 1; }

# ── Python ────────────────────────────────────────────────────────────────────
log "Checking Python 3.8+..."
PY=""
for candidate in python3 python; do
    if command -v "$candidate" &>/dev/null && "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3,8) else 1)' 2>/dev/null; then
        PY="$candidate"
        break
    fi
done
[[ -n "$PY" ]] || err "Python 3.8+ not found. Install it from https://python.org and re-run."
ok "$(${PY} --version)"

# ── omniscan ──────────────────────────────────────────────────────────────────
log "Installing omniscan..."
PIP=""
for candidate in pip3 pip; do
    command -v "$candidate" &>/dev/null && PIP="$candidate" && break
done
[[ -n "$PIP" ]] || PIP="$PY -m pip"

$PIP install --quiet --upgrade omniscan
ok "omniscan $($PY -c 'import omniscan; print(omniscan.__version__)')"

# ── PhoneInfoga ───────────────────────────────────────────────────────────────
log "Detecting platform for PhoneInfoga..."

OS=$(uname -s)
ARCH=$(uname -m)
ASSET=""

case "$OS" in
    Linux*)
        case "$ARCH" in
            x86_64)         ASSET="phoneinfoga_linux_x86_64.tar.gz" ;;
            aarch64|arm64)  ASSET="phoneinfoga_linux_arm64.tar.gz"  ;;
            *) warn "Unsupported Linux arch '$ARCH' — skipping PhoneInfoga install." ;;
        esac ;;
    Darwin*)
        case "$ARCH" in
            arm64)   ASSET="phoneinfoga_macOS_arm64.tar.gz"  ;;
            x86_64)  ASSET="phoneinfoga_macOS_x86_64.tar.gz" ;;
            *) warn "Unsupported macOS arch '$ARCH' — skipping PhoneInfoga install." ;;
        esac ;;
    *) warn "PhoneInfoga auto-install not supported on $OS. Install manually: https://github.com/sundowndev/phoneinfoga/releases" ;;
esac

if [[ -z "$ASSET" ]]; then
    echo ""
    log "omniscan is ready (without phone scanning). To add it later, re-run this script on a supported platform."
    exit 0
fi

log "Fetching latest PhoneInfoga release tag..."
LATEST=$(curl -fsSL "https://api.github.com/repos/${PHONEINFOGA_REPO}/releases/latest" \
    | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
[[ -n "$LATEST" ]] || err "Could not fetch latest PhoneInfoga version from GitHub API."

URL="https://github.com/${PHONEINFOGA_REPO}/releases/download/${LATEST}/${ASSET}"
log "Downloading PhoneInfoga ${LATEST}..."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -fsSL --progress-bar -o "$TMP/phoneinfoga.tar.gz" "$URL"
tar -xzf "$TMP/phoneinfoga.tar.gz" -C "$TMP"

# prefer system bin; fall back to ~/.local/bin without sudo
if [[ -w "$SYSTEM_BIN" ]]; then
    install -m 755 "$TMP/phoneinfoga" "$SYSTEM_BIN/phoneinfoga"
    INSTALLED_PATH="$SYSTEM_BIN/phoneinfoga"
elif command -v sudo &>/dev/null; then
    sudo install -m 755 "$TMP/phoneinfoga" "$SYSTEM_BIN/phoneinfoga"
    INSTALLED_PATH="$SYSTEM_BIN/phoneinfoga"
else
    LOCAL_BIN="$HOME/.local/bin"
    mkdir -p "$LOCAL_BIN"
    install -m 755 "$TMP/phoneinfoga" "$LOCAL_BIN/phoneinfoga"
    INSTALLED_PATH="$LOCAL_BIN/phoneinfoga"
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        warn "~/.local/bin is not in PATH. Add this to your shell profile:"
        warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
fi

ok "PhoneInfoga ${LATEST} → ${INSTALLED_PATH}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
log "All done. Try it:"
printf "  omniscan johndoe --sherlock\n"
printf "  omniscan +12025551234 --phoneinfoga\n"
printf "  omniscan johndoe +12025551234 --sherlock --phoneinfoga\n"
