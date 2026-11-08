#!/usr/bin/env bash
# Helper invoked by `wl-paste --type ... --watch`.
# Reads clipboard data directly from stdin (provided by wl-paste --watch) to avoid recursive wl-paste deadlocks.

set -u

mode="${1:-text}"
if [ "${CLIPBOARD_STATE:-data}" != "data" ]; then
    exit 0
fi

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/hyprshell/clip"
mkdir -p "$cache_dir"

if [ "$mode" = "image" ]; then
    tmp="$cache_dir/.tmp-$$.png"
    cat > "$tmp" 2>/dev/null || { rm -f "$tmp"; exit 0; }
    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        exit 0
    fi
    dims="$(identify -format '%wx%h' "$tmp" 2>/dev/null || true)"
    if [ -z "$dims" ]; then
        rm -f "$tmp"
        exit 0
    fi
    hash="$(sha256sum "$tmp" | awk '{print substr($1,1,16)}')"
    dest="$cache_dir/clip-$hash.png"
    mv -f "$tmp" "$dest"
    jq -nc --arg img "$dest" --arg txt "Image ($dims)" '{type: "image", image: $img, text: $txt}'
    exit 0
fi

if [ "$mode" = "text" ]; then
    txt="$(cat 2>/dev/null || true)"
    [ -z "$txt" ] && exit 0
    if [ "${#txt}" -gt 50000 ]; then
        exit 0
    fi
    # Ignore binary PNG headers or browser <img> HTML wrappers when copying an image
    if [[ "$txt" == $'\x89PNG'* ]] || [[ "$txt" =~ ^\<meta\ http-equiv=\"content-type\".*\<img\  ]]; then
        exit 0
    fi
    jq -nc --arg txt "$txt" '{type: "text", image: "", text: $txt}'
fi
