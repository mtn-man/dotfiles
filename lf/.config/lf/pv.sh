#!/bin/bash
# Preview script for lf
# - Text: bat (Markdown: mdcat if available)
# - Images: kitten icat when available, else chafa symbols
# - HEIC/HEIF: convert to JPEG via sips, then preview
# - Videos: embedded thumbnail only (silent no-preview if unavailable)
set -o pipefail

file="$1"
w="${2:-80}"
h="${3:-40}"
x="${4:-0}"
y="${5:-0}"

case "$x" in
    ''|*[!0-9]*) x=0 ;;
esac
case "$y" in
    ''|*[!0-9]*) y=0 ;;
esac

if [ -z "$file" ] || [ ! -e "$file" ]; then
    exit 0
fi

mimetype=$(file --mime-type -b "$file" 2>/dev/null || printf '%s' "application/octet-stream")

# Extension (for cases where markdown reports as text/plain)
ext="${file##*.}"
ext_lc="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

prefer_graphics_protocol() {
    [ "${TERM_PROGRAM:-}" = "ghostty" ] || [ -n "${KITTY_WINDOW_ID:-}" ] || [ "${TERM:-}" = "xterm-kitty" ]
}

can_use_kitten_graphics() {
    have_cmd kitten && prefer_graphics_protocol
}

# Set to 1 when a graphics preview was sent directly to the terminal.
GRAPHICS_RENDERED=0

render_graphics_file() {
    local src="$1"
    local geometry="${w}x${h}@${x}x${y}"
    can_use_kitten_graphics || return 1

    if kitten icat --silent --stdin=no --transfer-mode=file --place "$geometry" "$src" < /dev/null > /dev/tty 2>/dev/null; then
        GRAPHICS_RENDERED=1
        return 0
    fi
    return 1
}

render_chafa_symbols_file() {
    local src="$1"
    have_cmd chafa || return 1
    chafa -f symbols --animate=off --size "${w}x${h}" --optimize 9 "$src" 2>/dev/null
}

preview_text() {
    if [ "$mimetype" = "text/markdown" ] || [ "$ext_lc" = "md" ] || [ "$ext_lc" = "markdown" ]; then
        if have_cmd mdcat; then
            mdcat --columns "$w" "$file"
            return 0
        fi
    fi

    if have_cmd bat; then
        bat --color=always --style=plain --terminal-width="$w" "$file"
        return 0
    fi

    cat "$file"
}

preview_image() {
    local src="$1"
    if render_graphics_file "$src"; then
        return 0
    fi
    render_chafa_symbols_file "$src" || return 1
    return 0
}

preview_heic() {
    local cell_w_px=12
    local cell_h_px=20
    local px_w=$(( w * cell_w_px ))
    local px_h=$(( h * cell_h_px ))
    local cache_dir="$HOME/Library/Caches/lf"
    local tmpfile
    local status

    mkdir -p "$cache_dir" 2>/dev/null || return 1
    tmpfile=$(mktemp "$cache_dir/preview-XXXXXX" 2>/dev/null) || return 1

    sips -s format jpeg \
         -s formatOptions 80 \
         -s profile "/System/Library/ColorSync/Profiles/sRGB Profile.icc" \
         --resampleWidth "$px_w" \
         --resampleHeight "$px_h" \
         "$file" \
         --out "$tmpfile" \
         >/dev/null 2>&1 || {
        rm -f "$tmpfile"
        return 1
    }

    if [ -s "$tmpfile" ]; then
        preview_image "$tmpfile"
        status=$?
        rm -f "$tmpfile"
        return $status
    fi

    rm -f "$tmpfile"
    return 1
}

preview_video_embedded_thumb_only() {
    local src="$1"
    local cache_dir="$HOME/Library/Caches/lf"
    local tmpfile
    local status
    local attached_stream_index
    local second_codec

    have_cmd ffmpeg || return 1
    if ! can_use_kitten_graphics && ! have_cmd chafa; then
        return 1
    fi
    mkdir -p "$cache_dir" 2>/dev/null || return 1
    tmpfile=$(mktemp "$cache_dir/preview-video-XXXXXX" 2>/dev/null || true)

    # 1) Try explicit attached picture stream (common in cover-art metadata).
    attached_stream_index=$(
        ffprobe -hide_banner -loglevel error -show_streams "$src" 2>/dev/null | \
            awk -F= '
                /^\[STREAM\]/ { idx=""; attached=0 }
                /^index=/ { idx=$2 }
                /^DISPOSITION:attached_pic=/ { attached=$2 }
                /^\[\/STREAM\]/ {
                    if (attached == 1 && idx != "") {
                        print idx
                        exit
                    }
                }
            '
    )
    if [ -n "$attached_stream_index" ] && [ -n "$tmpfile" ]; then
        if ffmpeg -hide_banner -loglevel error -y -i "$src" -map "0:${attached_stream_index}" -frames:v 1 -an -f image2 "$tmpfile" >/dev/null 2>&1 && [ -s "$tmpfile" ]; then
            preview_image "$tmpfile"
            status=$?
            rm -f "$tmpfile"
            return $status
        fi
    fi

    [ -n "$tmpfile" ] && rm -f "$tmpfile"

    # 2) Try yt-dlp-style embedded thumbnail stream (often 0:v:1).
    # Only run when stream 1 exists and uses an image-like codec.
    second_codec=$(ffprobe -hide_banner -loglevel error -select_streams v:1 -show_entries stream=codec_name -of default=nw=1:nk=1 "$src" 2>/dev/null | head -n 1)
    case "$second_codec" in
        mjpeg|png|webp|bmp|gif|tiff)
            # Copy-only keeps this thumbnail-only and avoids regular frame rendering.
            tmpfile=$(mktemp "$cache_dir/preview-video-stream-XXXXXX" 2>/dev/null || true)
            if [ -n "$tmpfile" ]; then
                if ffmpeg -hide_banner -loglevel error -y -i "$src" -map 0:v:1 -c:v copy -f image2 "$tmpfile" >/dev/null 2>&1 && [ -s "$tmpfile" ]; then
                    preview_image "$tmpfile"
                    status=$?
                    rm -f "$tmpfile"
                    return $status
                fi
                rm -f "$tmpfile"
            fi
            ;;
    esac

    [ -n "$tmpfile" ] && rm -f "$tmpfile"
    return 1
}

case "$mimetype" in
    text/*|application/json|application/javascript|application/xml|application/x-sh|application/toml)
        preview_text
        ;;

    image/heic|image/heif)
        GRAPHICS_RENDERED=0
        if preview_heic; then
            [ "$GRAPHICS_RENDERED" -eq 1 ] && exit 1
        fi
        ;;

    image/*)
        GRAPHICS_RENDERED=0
        if preview_image "$file"; then
            [ "$GRAPHICS_RENDERED" -eq 1 ] && exit 1
        fi
        ;;

    video/*)
        # For mp4/mkv and other videos: embedded thumbnail only.
        GRAPHICS_RENDERED=0
        if preview_video_embedded_thumb_only "$file"; then
            [ "$GRAPHICS_RENDERED" -eq 1 ] && exit 1
        fi
        ;;

    *)
        # Fallback for non-text and non-media files.
        echo "$mimetype"
        ls -lh "$file"
        ;;
esac

exit 0
