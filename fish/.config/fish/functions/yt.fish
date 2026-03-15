function yt --description 'Download YouTube videos with options'
    # Downloads to ~/Movies/YouTube with embedded thumbnails and metadata
    # Maintains download archive to prevent re-downloading

    # Default format settings
    set -l min_h 720
    set -l max_h 1440
    set -l codec_pref vp9

    # Check for yt-dlp
    if not command -q yt-dlp
        echo "yt: yt-dlp not found. Install with: brew install yt-dlp" >&2
        return 127
    end
    
    # Parse arguments using fish's built-in argparse
    argparse -n yt 'h/help' 'o/open' 'i/interactive' -- $argv
    or return 1

    # Show help
    if set -q _flag_help
        echo "Usage: yt [OPTIONS] [URL]"
        echo ""
        echo "Options:"
        echo "  -o, --open         Open video after download"
        echo "  -i, --interactive  Choose resolution and codec"
        echo "  -h, --help         Show this help"
        echo ""
        echo "If no URL provided, uses clipboard content"
        echo ""
        echo "Use cookies.txt browser extension to export cookies" 
        echo "to a file named `.ytcookies.txt` in your output folder"
        return 0
    end

    # Get URL from remaining args or clipboard
    set -l url
    if test (count $argv) -gt 0
        set url (string trim -- $argv[1])
    else
        set url (pbpaste | string trim)
    end

    if test -z "$url"
        echo "yt: no URL provided and clipboard is empty" >&2
        return 1
    end

    # Setup output directory
    set -l outdir "$HOME/Movies/YouTube"
    mkdir -p "$outdir"
    or begin
        echo "yt: Failed to create output directory: $outdir" >&2
        return 1
    end
    
    # Interactive mode: single-key selection
    if set -q _flag_interactive
        echo "Select Max Resolution:"
        echo "  [1] 1080p"
        echo "  [2] 1440p (Default)"
        echo "  [3] 2160p (4K)"
        read -n 1 -P "Choice > " res_choice
        echo

        switch $res_choice
            case 1
                set max_h 1080
            case 3
                set max_h 2160
            case '*'
                set max_h 1440
        end

        echo ""
        echo "Select Preferred Codec:"
        echo "  [1] VP9 (Default)"
        echo "  [2] AV1"
        echo "  [3] H.264"
        read -n 1 -P "Choice > " codec_choice
        echo

        switch $codec_choice
            case 2
                set codec_pref av01
            case 3
                set codec_pref avc1
            case '*'
                set codec_pref vp9
        end

        echo ""
        set -l codec_name
        switch $codec_pref
            case vp9
                set codec_name "VP9"
            case av01
                set codec_name "AV1"
            case avc1
                set codec_name "H.264"
            case '*'
                set codec_name (string upper $codec_pref)
        end

        echo "Downloading: "$max_h"p / $codec_name / MP4"
        echo ""
    end

    # Build yt-dlp command
    #
    # Policy:
    # - Prefer highest resolution up to max_h, with a minimum floor min_h (when possible)
    # - Within that, prefer the chosen codec via explicit filter: [vcodec^=...]
    # - If preferred codec isn't available at that res, fall back to any codec at that res
    # - If nothing >= min_h exists, fall back below the floor so something still downloads
    #
    # Sorting:
    # - Keep sorting focused on resolution/fps; codec preference is handled by -f fallbacks
    set -l format_sel \
    "bestvideo[height<=$max_h][height>=$min_h][vcodec^=$codec_pref]+bestaudio/"\
    "bestvideo[height<=$max_h][height>=$min_h]+bestaudio/"\
    "best[height<=$max_h][height>=$min_h]/"\
    "bestvideo[height<=$max_h][vcodec^=$codec_pref]+bestaudio/"\
    "bestvideo[height<=$max_h]+bestaudio/"\
    "best[height<=$max_h]"

    set -l yt_dlp_cmd yt-dlp \
        -f "$format_sel" \
        -S "res,fps" \
        --merge-output-format mp4 \
        --embed-thumbnail \
        --embed-metadata \
        --download-archive "$outdir/.yt-archive.txt" \
        --concurrent-fragments 5 \
        --buffer-size 1M \
        -o "%(title)s.%(ext)s" \
        --paths "$outdir" \
        --cookies-from-browser safari\
        --no-overwrites

    # Add --exec flag if opening after download
    if set -q _flag_open
        set yt_dlp_cmd $yt_dlp_cmd --exec 'open {}'
    end

    # Add URL
    set yt_dlp_cmd $yt_dlp_cmd -- "$url"

    # Run yt-dlp with the constructed argument list
    $yt_dlp_cmd
    or begin
        echo "yt: Download failed" >&2
        return 1
    end

    # Play a sound only on success
    if status --is-interactive
        if command -q afplay
            afplay /System/Library/Sounds/Glass.aiff &
        end
    end

    # Context-aware completion message
    if set -q _flag_open
        echo "✓ Downloaded and opened"
    else
        echo "✓ Downloaded to: $outdir"
    end
end
