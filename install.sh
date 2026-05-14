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

PIP_CMD=""
for _c in pip3 pip; do
    command -v "$_c" &>/dev/null && PIP_CMD="$_c" && break
done
[[ -n "$PIP_CMD" ]] || PIP_CMD="$PY -m pip"

OMNISCAN_OK=0

# 1. pipx — correct tool for PEP 668 / Debian-based systems
if command -v pipx &>/dev/null; then
    if pipx install omniscan >/dev/null 2>&1 || pipx upgrade omniscan >/dev/null 2>&1; then
        pipx ensurepath >/dev/null 2>&1 || true
        export PATH="$HOME/.local/bin:$PATH"
        OMNISCAN_OK=1
    fi
fi

# 2. plain pip (venvs, Homebrew Python, older distros)
if [[ $OMNISCAN_OK -eq 0 ]]; then
    if $PIP_CMD install --quiet --upgrade omniscan >/dev/null 2>&1; then
        OMNISCAN_OK=1
    fi
fi

# 3. pip --break-system-packages (PEP 668 without pipx)
if [[ $OMNISCAN_OK -eq 0 ]]; then
    warn "Plain pip blocked (PEP 668). Retrying with --break-system-packages..."
    if $PIP_CMD install --quiet --upgrade --break-system-packages omniscan >/dev/null 2>&1; then
        OMNISCAN_OK=1
    fi
fi

if [[ $OMNISCAN_OK -eq 0 ]]; then
    err "Could not install omniscan. Try: sudo apt install pipx && pipx install omniscan"
fi

export PATH="$HOME/.local/bin:$PATH"
OMNISCAN_VER=$(omniscan --version 2>/dev/null | awk '{print $NF}' \
    || $PY -c 'import omniscan; print(omniscan.__version__)' 2>/dev/null \
    || echo "installed")
ok "omniscan ${OMNISCAN_VER}"

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
