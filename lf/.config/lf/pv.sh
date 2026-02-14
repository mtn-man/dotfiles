#!/bin/bash
# Preview script for lf + kitty icat
# - Text: bat
# - Images: kitty icat (HEIC/HEIF are converted to JPEG and streamed)
# - Videos: extract embedded thumbnail stream (fast for yt-dlp files)
set -o pipefail

file="$1"
w="$2"
h="$3"
x="$4"
y="$5"

# Standard Kitty icat placement format: <width>x<height>@<x>x<y>
geometry="${w}x${h}@${x}x${y}"
mimetype=$(file --mime-type -b "$file")

case "$mimetype" in
    text/*|application/json|application/javascript|application/xml|application/x-sh|application/toml)
        bat --color=always --style=plain --terminal-width="$w" "$file"
        ;;

    image/heic|image/heif)
        # lf passes w/h in terminal *cells*, but ImageMagick wants *pixels*.
        # Approximate px per cell (kitty typical): ~9x18. Bump a bit for clarity.
        cell_w_px=8
        cell_h_px=16

        px_w=$(( w * cell_w_px ))
        px_h=$(( h * cell_h_px ))

        magick "$file"[0] \
            -auto-orient \
            -colorspace sRGB \
            -depth 8 \
            -resize "${px_w}x${px_h}>" \
            -strip \
            jpg:- 2>/dev/null | \
          kitty +kitten icat --silent --stdin=yes --transfer-mode=stream --place "$geometry" > /dev/tty && exit 1
        ;;


    image/*)
        # We use < /dev/null here because icat is reading directly from the $file path.
        # This prevents it from trying to read from lf's standard input.
        kitty +kitten icat --silent --stdin=no --transfer-mode=file --place "$geometry" "$file" \
            < /dev/null > /dev/tty
        exit 1
        ;;

    video/*)
        # Extract embedded thumbnail (stream 0:v:1) instead of generating frame
        # yt-dlp embeds thumbnails as second video stream, making this fast
        # Pipe directly to kitty for display without temp files
        # If no thumbnail exists (ffmpeg fails), fall through silently
        if ffmpeg -hide_banner -loglevel error -i "$file" -map 0:v:1 -c:v copy -f image2pipe - 2>/dev/null | \
           kitty +kitten icat --silent --stdin=yes --transfer-mode=stream --place "$geometry" > /dev/tty; then
           exit 1 # exit 1 tells lf to not clear the preview
        fi
        ;;

    *)
        # Only reached for non-text, non-image, and non-video files.
        echo "$mimetype"
        ls -lh "$file"
        ;;
esac
