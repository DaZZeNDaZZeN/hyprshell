#!/usr/bin/env bash
# Secure clipboard storage helper for Hyprshell.
# Uses KWallet (via kwallet-query) when available; otherwise stores nothing on disk (RAM only).

set -u
umask 077

action="${1:-load}"

if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
    ram_dir="$XDG_RUNTIME_DIR/hyprshell"
else
    ram_dir="/dev/shm/hyprshell-$(id -u)"
fi

mkdir -p -m 700 "$ram_dir" "$ram_dir/clip" 2>/dev/null || true
chmod 700 "$ram_dir" "$ram_dir/clip" 2>/dev/null || true

staging_file="$ram_dir/.clip-staging.json"
legacy_json="${XDG_CONFIG_HOME:-$HOME/.config}/hyprshell/clipboard.json"
legacy_cache="${XDG_CACHE_HOME:-$HOME/.cache}/hyprshell/clip"

# Always remove legacy plaintext disk cache if present
if [ -d "$legacy_cache" ]; then
    rm -rf "$legacy_cache" 2>/dev/null || true
fi

detect_wallet() {
    command -v kwallet-query >/dev/null 2>&1 || return 1
    local kwrc="${XDG_CONFIG_HOME:-$HOME/.config}/kwalletrc"
    if [ -f "$kwrc" ] && grep -qiE '^[[:space:]]*Enabled[[:space:]]*=[[:space:]]*false' "$kwrc" 2>/dev/null; then
        return 1
    fi

    if command -v busctl >/dev/null 2>&1; then
        local enabled
        enabled="$(busctl --user --timeout=2 call org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet isEnabled 2>/dev/null | awk '{print $2}')"
        if [ "$enabled" = "false" ]; then
            return 1
        fi
    fi

    local wallet=""
    if command -v busctl >/dev/null 2>&1; then
        wallet="$(busctl --user --timeout=2 call org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet localWallet 2>/dev/null | sed -n 's/^s "\(.*\)"$/\1/p')"
    fi
    if [ -z "$wallet" ] && [ -f "$kwrc" ]; then
        wallet="$(sed -n 's/^[[:space:]]*Default Wallet[[:space:]]*=[[:space:]]*//p' "$kwrc" | head -n1)"
    fi
    [ -z "$wallet" ] && wallet="kdewallet"

    kwallet-query -l "$wallet" >/dev/null 2>&1 || return 1
    printf '%s' "$wallet"
    return 0
}

filter_existing_images() {
    python3 -c '
import json, os, sys
try:
    items = json.loads(sys.stdin.read() or "[]")
    if not isinstance(items, list):
        items = []
except Exception:
    items = []
out = []
for e in items:
    if not isinstance(e, dict):
        continue
    if e.get("type") == "image":
        p = e.get("image") or ""
        if not p or not os.path.isfile(p):
            continue
    out.append(e)
print(json.dumps(out))
' 2>/dev/null || printf '[]'
}

if [ "$action" = "load" ]; then
    legacy_data=""
    if [ -f "$legacy_json" ]; then
        legacy_data="$(cat "$legacy_json" 2>/dev/null || true)"
        shred -u "$legacy_json" 2>/dev/null || rm -f "$legacy_json" 2>/dev/null || true
    fi

    if wallet="$(detect_wallet)"; then
        raw=""
        if kwallet-query -f hyprshell -l "$wallet" 2>/dev/null | grep -qx "clipboard"; then
            raw="$(kwallet-query -f hyprshell -r clipboard "$wallet" 2>/dev/null || true)"
        fi
        if [ -z "$raw" ] && [ -n "$legacy_data" ]; then
            cleaned="$(printf '%s' "$legacy_data" | filter_existing_images)"
            printf '%s' "$cleaned" | kwallet-query -f hyprshell -w clipboard "$wallet" >/dev/null 2>&1 || true
            raw="$cleaned"
        fi
        cleaned="$(printf '%s' "${raw:-[]}" | filter_existing_images)"
        jq -nc --argjson entries "$cleaned" '{backend: "kwallet", entries: $entries}'
    else
        rm -f "$staging_file" 2>/dev/null || true
        cleaned="$(printf '%s' "${legacy_data:-[]}" | filter_existing_images)"
        jq -nc --argjson entries "$cleaned" '{backend: "ram", entries: $entries}'
    fi
    exit 0
fi

if [ "$action" = "save" ]; then
    if [ ! -f "$staging_file" ]; then
        exit 0
    fi
    data="$(cat "$staging_file" 2>/dev/null || true)"
    shred -u "$staging_file" 2>/dev/null || rm -f "$staging_file" 2>/dev/null || true
    [ -z "$data" ] && exit 0
    if wallet="$(detect_wallet)"; then
        printf '%s' "$data" | kwallet-query -f hyprshell -w clipboard "$wallet" >/dev/null 2>&1 || true
    fi
    exit 0
fi
