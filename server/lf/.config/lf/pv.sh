#!/usr/bin/env bash
set -o pipefail

file="$1"
w="${2:-80}"

if [[ -z "$file" || ! -e "$file" ]]; then
    exit 0
fi

PREVIEW_CACHE_DIR="${LF_PREVIEW_CACHE_DIR:-$HOME/.cache/lf}"
DEP_CACHE_FILE="${PREVIEW_CACHE_DIR}/.dep_cache"
mkdir -p "$PREVIEW_CACHE_DIR" 2>/dev/null

PKGDB="/var/lib/rpm"
if [[ -f "$DEP_CACHE_FILE" && -d "$PKGDB" && "$PKGDB" -nt "$DEP_CACHE_FILE" ]]; then
    rm -f "$DEP_CACHE_FILE"
fi
if [[ -f "$DEP_CACHE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$DEP_CACHE_FILE"
else
    {
        echo "HAS_BAT=$(command -v bat >/dev/null 2>&1 && echo 1 || echo 0)"
        echo "HAS_EZA=$(command -v eza >/dev/null 2>&1 && echo 1 || echo 0)"
    } > "$DEP_CACHE_FILE"
    source "$DEP_CACHE_FILE"
fi

mimetype=$(file --mime-type -b "$file" 2>/dev/null || echo "application/octet-stream")

case "$mimetype" in
    text/*|application/json|application/javascript|application/xml|application/x-sh)
        if [[ "$HAS_BAT" -eq 1 ]]; then
            bat --color=always --style=plain --terminal-width="$w" "$file"
        else
            cat "$file"
        fi
        ;;
    *)
        echo "$mimetype"
        [[ "$HAS_EZA" -eq 1 ]] && eza -lh "$file" || ls -lh "$file"
        ;;
esac
