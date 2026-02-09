function lf --description 'lf with quit-and-cd integration'
    set -l tmp (mktemp)

    command lf -last-dir-path="$tmp" $argv

    if test -f "$tmp"
        set -l dir (cat "$tmp")
        rm -f "$tmp"

        if test -n "$dir"; and test -d "$dir"; and test "$dir" != (pwd)
            cd -- "$dir"
        end
    end
end
