function lf --description 'lf with quit-and-cd integration'
    set -l tmp (mktemp)
    set -lx LF_PREVIEW_CACHE_DIR "$HOME/Library/Caches/lf"

    if test -z "$tmp"
        set tmp "/tmp/lf-last-dir-$fish_pid"
        command touch "$tmp" 2>/dev/null
    end

    command mkdir -p "$LF_PREVIEW_CACHE_DIR/thumbs" 2>/dev/null

    # Evict thumbnails not accessed in 30 days and any stale tmp files older than 1 day
    find "$LF_PREVIEW_CACHE_DIR/thumbs" -maxdepth 1 -name "*.jpg" -mtime +30 -delete 2>/dev/null
    find "$LF_PREVIEW_CACHE_DIR/thumbs" -maxdepth 1 -name "*.tmp.*" -mtime +1 -delete 2>/dev/null

    command lf -last-dir-path="$tmp" $argv
    set -l lf_status $status

    if test -f "$tmp"
        set -l dir (cat "$tmp")

        if test -n "$dir"; and test -d "$dir"; and test "$dir" != (pwd)
            cd -- "$dir"
        end
    end

    rm -f "$tmp"

    return $lf_status
end
