#!/bin/sh
# Clear kitty-graphics previews only when we know one was rendered.
have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

prefer_graphics_protocol() {
    [ "${TERM_PROGRAM:-}" = "ghostty" ] || [ -n "${KITTY_WINDOW_ID:-}" ] || [ "${TERM:-}" = "xterm-kitty" ]
}

cache_dir="${LF_PREVIEW_CACHE_DIR:-$HOME/.cache/lf}"
marker="$cache_dir/.needs_graphics_clear"

have_cmd kitten || exit 0
prefer_graphics_protocol || exit 0
[ -f "$marker" ] || exit 0

if kitten icat --clear --stdin=no --silent --transfer-mode=memory < /dev/null > /dev/tty 2>/dev/null; then
    rm -f "$marker"
fi

exit 0
