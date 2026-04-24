#!/usr/bin/env bash
# Optimized Preview script for lf
# - Compatibility: Ghostty 1.x+ and Kitty
# - Performance: Cached dependency lookups
# - Media: yt-dlp style embedded thumbnail extraction only
# - Text: Simplified bat/color handling for all text
# Note: image previews require `kitten icat` (from the kitty package) even when
# using Ghostty, as Ghostty does not ship its own kitten binary.
set -o pipefail

file="$1"
w="${2:-80}"
h="${3:-40}"
x="${4:-0}"
y="${5:-0}"

# Sanitize coordinates
[[ "$x" =~ ^[0-9]+$ ]] || x=0
[[ "$y" =~ ^[0-9]+$ ]] || y=0

if [[ -z "$file" || ! -e "$file" ]]; then
    exit 0
fi

# Environment & Caching
PREVIEW_CACHE_DIR="${LF_PREVIEW_CACHE_DIR:-$HOME/.cache/lf}"
DEP_CACHE_FILE="${PREVIEW_CACHE_DIR}/.dep_cache"
GRAPHICS_CLEAR_MARKER="${PREVIEW_CACHE_DIR}/.needs_graphics_clear"
mkdir -p "$PREVIEW_CACHE_DIR/thumbs" 2>/dev/null

# --- SECTION 1: CENTRALIZED DEPENDENCY STATE ---
# Invalidate dep cache when the pacman package database changes (catches installs and removals).
PKGDB="/var/lib/pacman/local"
if [[ -f "$DEP_CACHE_FILE" && -d "$PKGDB" && "$PKGDB" -nt "$DEP_CACHE_FILE" ]]; then
    rm -f "$DEP_CACHE_FILE"
fi
if [[ -f "$DEP_CACHE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$DEP_CACHE_FILE"
else
    {
        echo "HAS_BAT=$(command -v bat >/dev/null 2>&1 && echo 1 || echo 0)"
        echo "HAS_KITTEN=$(command -v kitten >/dev/null 2>&1 && echo 1 || echo 0)"
        echo "HAS_FFMPEG=$(command -v ffmpeg >/dev/null 2>&1 && echo 1 || echo 0)"
        echo "HAS_FFPROBE=$(command -v ffprobe >/dev/null 2>&1 && echo 1 || echo 0)"
        echo "HAS_EZA=$(command -v eza >/dev/null 2>&1 && echo 1 || echo 0)"
    } > "$DEP_CACHE_FILE"
    source "$DEP_CACHE_FILE"
fi

# --- SECTION 2: UTILITIES ---
thumb_cache_path() {
    local src="$1"
    local stat_out
    stat_out=$(stat -c "%Y:%s" "$src" 2>/dev/null) || stat_out="0:0"
    local key
    key=$(printf '%s:%s' "$src" "$stat_out" | md5sum | awk '{print $1}')
    echo "${PREVIEW_CACHE_DIR}/thumbs/${key}.jpg"
}

prefer_graphics_protocol() {
    [[ "${TERM_PROGRAM:-}" == "ghostty" ]] || \
    [[ -n "${KITTY_WINDOW_ID:-}" ]] || \
    [[ "${TERM:-}" == "xterm-kitty" ]]
}

can_use_kitten_graphics() {
    [[ "$HAS_KITTEN" -eq 1 ]] && prefer_graphics_protocol
}

GRAPHICS_RENDERED=0
render_graphics_file() {
    local src="$1"
    local geometry="${w}x${h}@${x}x${y}"
    can_use_kitten_graphics || return 1

    if kitten icat --silent --stdin=no --transfer-mode=file --place "$geometry" \
        "$src" < /dev/null > /dev/tty 2>/dev/null; then
        GRAPHICS_RENDERED=1
        : > "$GRAPHICS_CLEAR_MARKER" 2>/dev/null
        return 0
    fi
    return 1
}

# --- SECTION 3: HANDLERS ---
preview_text() {
    if [[ "$HAS_BAT" -eq 1 ]]; then
        # Unified bat handler: automatic syntax detection based on file content/extension
        bat --color=always --style=plain --terminal-width="$w" "$file"
    else
        cat "$file"
    fi
}

preview_video_ytdlp() {
    [[ "$HAS_FFMPEG" -eq 1 && "$HAS_FFPROBE" -eq 1 ]] || return 1
    can_use_kitten_graphics || return 1

    # Check cache first to avoid expensive ffprobe call on cache hits
    local cached
    cached=$(thumb_cache_path "$file")
    if [[ -s "$cached" ]]; then
        touch "$cached"
        render_graphics_file "$cached"
        return 0
    fi

    # Specifically target yt-dlp style embedded thumbnails (usually stream v:1)
    # Check if stream 1 exists and is an image codec (mjpeg/webp/png/etc)
    local codec
    codec=$(ffprobe -v error -select_streams v:1 \
        -show_entries stream=codec_name \
        -of default=noprint_wrappers=1:nk=1 "$file" 2>/dev/null)

    case "$codec" in
        mjpeg|png|webp|bmp|gif|tiff)
            local tmp="${cached}.tmp.$$"
            # Extract the embedded thumbnail without transcoding (-c:v copy)
            if ffmpeg -hide_banner -loglevel error -y -i "$file" \
                -map 0:v:1 -frames:v 1 -c:v copy -f image2 "$tmp" >/dev/null 2>&1; then
                mv "$tmp" "$cached"
            else
                rm -f "$tmp"
                return 1
            fi
            render_graphics_file "$cached"
            return 0
            ;;
    esac
    return 1
}

# --- SECTION 4: MAIN DISPATCH ---
mimetype=$(file --mime-type -b "$file" 2>/dev/null || echo "application/octet-stream")

case "$mimetype" in
    text/*|application/json|application/javascript|application/xml|application/x-sh)
        preview_text
        ;;
    image/*)
        render_graphics_file "$file" && exit 1
        ;;
    video/*)
        # Optimized: only attempt embedded yt-dlp thumbnail extraction
        preview_video_ytdlp && [[ "$GRAPHICS_RENDERED" -eq 1 ]] && exit 1
        ;;
    *)
        # Fallback for non-text/non-media
        echo "$mimetype"
        [[ "$HAS_EZA" -eq 1 ]] && eza -lh "$file" || ls -lh "$file"
        ;;
esac
