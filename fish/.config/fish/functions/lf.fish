function lf --description 'lf with quit-and-cd integration'
    set -l tmp (mktemp)
    set -l thumb_cache (mktemp -d 2>/dev/null)

    if test -z "$tmp"
        set tmp "/tmp/lf-last-dir-$fish_pid"
        command touch "$tmp" 2>/dev/null
    end

    if test -z "$thumb_cache"
        set thumb_cache "/tmp/lf-preview-$fish_pid"
        command mkdir -p "$thumb_cache" 2>/dev/null
    end

    if test -d "$thumb_cache"
        set -lx LF_PREVIEW_CACHE_DIR "$thumb_cache"
        command lf -last-dir-path="$tmp" $argv
    else
        command lf -last-dir-path="$tmp" $argv
    end
    set -l lf_status $status

    if test -f "$tmp"
        set -l dir (cat "$tmp")

        if test -n "$dir"; and test -d "$dir"; and test "$dir" != (pwd)
            cd -- "$dir"
        end
    end

    rm -f "$tmp"

    if test -n "$thumb_cache"; and test -d "$thumb_cache"
        command rm -rf -- "$thumb_cache"
    end

    return $lf_status
end
