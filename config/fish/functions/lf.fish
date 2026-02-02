function lf --description 'lf with quit-and-cd integration'
    set -l tmp (mktemp)
    # Using 'command lf' ensures we call the binary, not the function recursively
    command lf -last-dir-path=$tmp $argv
    if test -f $tmp
        set -l dir (cat $tmp)
        rm -f $tmp
        if test -d "$dir" -a "$dir" != (pwd)
            cd "$dir"
        end
    end
end
