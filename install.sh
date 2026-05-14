#!/usr/bin/env bash
# omniscan installer — downloads pre-built binaries for omniscan + PhoneInfoga
# Usage: curl -fsSL https://raw.githubusercontent.com/HubDamian95/omniscan/master/install.sh | bash
set -euo pipefail

OMNISCAN_REPO="HubDamian95/omniscan"
PHONEINFOGA_REPO="sundowndev/phoneinfoga"
LOCAL_BIN="$HOME/.local/bin"

log()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
ok()   { printf '\e[1;32m ok\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33mwarn:\e[0m %s\n' "$*" >&2; }
err()  { printf '\e[1;31merror:\e[0m %s\n' "$*" >&2; exit 1; }

# ── platform detection ────────────────────────────────────────────────────────
OS=$(uname -s)
ARCH=$(uname -m)

OMNISCAN_ASSET=""
PHONEINFOGA_ASSET=""

case "$OS" in
    Linux*)
        case "$ARCH" in
            x86_64)
                OMNISCAN_ASSET="omniscan-linux-x86_64"
                PHONEINFOGA_ASSET="phoneinfoga_linux_x86_64.tar.gz"
                ;;
            aarch64|arm64)
                PHONEINFOGA_ASSET="phoneinfoga_linux_arm64.tar.gz"
                warn "No omniscan binary for Linux arm64 yet — only PhoneInfoga will be installed."
                ;;
            *) err "Unsupported Linux architecture: $ARCH" ;;
        esac
        ;;
    Darwin*)
        # arm64 binary runs on both Apple Silicon and Intel (Rosetta 2)
        OMNISCAN_ASSET="omniscan-macos-arm64"
        case "$ARCH" in
            arm64)  PHONEINFOGA_ASSET="phoneinfoga_macOS_arm64.tar.gz"  ;;
            x86_64) PHONEINFOGA_ASSET="phoneinfoga_macOS_x86_64.tar.gz" ;;
            *) err "Unsupported macOS architecture: $ARCH" ;;
        esac
        ;;
    *) err "Unsupported OS: $OS — install manually from https://github.com/HubDamian95/omniscan/releases" ;;
esac

# ── helpers ───────────────────────────────────────────────────────────────────
_latest_tag() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
        | grep '"tag_name"' | head -1 \
        | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
}

_install_bin() {
    local src="$1" name="$2"
    if [[ -w "/usr/local/bin" ]]; then
        install -m 755 "$src" "/usr/local/bin/$name"
        echo "/usr/local/bin/$name"
    elif command -v sudo &>/dev/null; then
        sudo install -m 755 "$src" "/usr/local/bin/$name"
        echo "/usr/local/bin/$name"
    else
        mkdir -p "$LOCAL_BIN"
        install -m 755 "$src" "$LOCAL_BIN/$name"
        echo "$LOCAL_BIN/$name"
    fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── omniscan ──────────────────────────────────────────────────────────────────
if [[ -n "$OMNISCAN_ASSET" ]]; then
    log "Fetching latest omniscan release..."
    OMNISCAN_VER=$(_latest_tag "$OMNISCAN_REPO")
    [[ -n "$OMNISCAN_VER" ]] || err "Could not fetch omniscan version from GitHub API."

    OMNISCAN_URL="https://github.com/${OMNISCAN_REPO}/releases/download/${OMNISCAN_VER}/${OMNISCAN_ASSET}"
    log "Downloading omniscan ${OMNISCAN_VER}..."
    curl -fsSL --progress-bar -o "$TMP/omniscan" "$OMNISCAN_URL"

    OMNISCAN_PATH=$(_install_bin "$TMP/omniscan" "omniscan")
    ok "omniscan ${OMNISCAN_VER} → ${OMNISCAN_PATH}"
fi

# ── PhoneInfoga ───────────────────────────────────────────────────────────────
if [[ -n "$PHONEINFOGA_ASSET" ]]; then
    log "Fetching latest PhoneInfoga release..."
    PHONEINFOGA_VER=$(_latest_tag "$PHONEINFOGA_REPO")

    if [[ -n "$PHONEINFOGA_VER" ]]; then
        PHONEINFOGA_URL="https://github.com/${PHONEINFOGA_REPO}/releases/download/${PHONEINFOGA_VER}/${PHONEINFOGA_ASSET}"
        log "Downloading PhoneInfoga ${PHONEINFOGA_VER}..."
        curl -fsSL --progress-bar -o "$TMP/phoneinfoga.tar.gz" "$PHONEINFOGA_URL"
        tar -xzf "$TMP/phoneinfoga.tar.gz" -C "$TMP"

        PHONEINFOGA_PATH=$(_install_bin "$TMP/phoneinfoga" "phoneinfoga")
        ok "PhoneInfoga ${PHONEINFOGA_VER} → ${PHONEINFOGA_PATH}"
    else
        warn "Could not fetch PhoneInfoga version — skipping. Install manually: https://github.com/sundowndev/phoneinfoga/releases"
    fi
fi

# ── Maigret + GHunt (via pipx) ───────────────────────────────────────────────
log "Installing Maigret and GHunt..."
if command -v pipx &>/dev/null; then
    export PATH="$HOME/.local/bin:$PATH"
    if pipx install maigret >/dev/null 2>&1; then
        ok "Maigret installed"
    else
        warn "Maigret install failed — install manually: pipx install maigret"
    fi
    if pipx install ghunt >/dev/null 2>&1; then
        ok "GHunt installed (run 'ghunt login' once to authenticate)"
    else
        warn "GHunt install failed — install manually: pipx install ghunt"
    fi
else
    warn "pipx not found — skipping Maigret and GHunt."
    warn "To install: sudo apt install pipx && pipx install maigret && pipx install ghunt"
fi

# ── PATH hint ─────────────────────────────────────────────────────────────────
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]] && [[ -f "$LOCAL_BIN/omniscan" || -f "$LOCAL_BIN/phoneinfoga" ]]; then
    echo ""
    warn "~/.local/bin is not in your PATH. Add this line to ~/.bashrc or ~/.zshrc:"
    warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    warn "Then reload: source ~/.bashrc"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
log "All done. Try it:"
printf "  omniscan johndoe --sherlock\n"
printf "  omniscan +12025551234 --phoneinfoga\n"
printf "  omniscan johndoe +12025551234 --sherlock --phoneinfoga\n"
