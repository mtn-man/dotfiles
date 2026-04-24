function lp
    set -l i 1
    for dir in $PATH
        if test -d "$dir"
            printf "%2d  %s\n" $i $dir
        else
            printf "%2d  %s (missing)\n" $i $dir
        end
        set i (math $i + 1)
    end
end
