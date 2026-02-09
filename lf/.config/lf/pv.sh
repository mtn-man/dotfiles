#!/bin/bash
# Ensures the script fails if the first part of the pipe (ffmpeg) fails
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
    
    image/*)
        # We use < /dev/null here because icat is reading directly from the $file path.
        # This prevents it from trying to read from lf's standard input.
        kitty +kitten icat --silent --stdin=no --transfer-mode=file --place "$geometry" "$file" < /dev/null > /dev/tty
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
