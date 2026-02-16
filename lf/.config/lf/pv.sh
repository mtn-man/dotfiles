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
	    # Convert terminal cell dimensions to approximate pixels
	    cell_w_px=10
	    cell_h_px=18

	    px_w=$(( w * cell_w_px ))
	    px_h=$(( h * cell_h_px ))

	    # Ensure user cache directory exists
	    cache_dir="$HOME/Library/Caches/lf"
	    mkdir -p "$cache_dir"

	    # Create a temporary JPEG output file
	    tmpfile=$(mktemp "$cache_dir/preview-XXXXXX.jpg")

	    # Convert HEIC → JPEG using macOS-native sips
		sips -s format jpeg \
		     -s formatOptions 80 \
		     -s profile "/System/Library/ColorSync/Profiles/sRGB Profile.icc" \
		     --resampleWidth "$px_w" \
		     --resampleHeight "$px_h" \
		     "$file" \
		     --out "$tmpfile" \
		     >/dev/null 2>&1

	    # If conversion succeeded, stream the JPEG to kitty icat
	    if [ -s "$tmpfile" ]; then
	        cat "$tmpfile" | \
	            kitty +kitten icat \
	                --silent \
	                --stdin=yes \
	                --transfer-mode=stream \
	                --place "$geometry" \
	                > /dev/tty

	        rm -f "$tmpfile"
	        exit 1
	    fi

	    # Cleanup on failure
	    rm -f "$tmpfile"
	    exit 0
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
