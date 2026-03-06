function lp --description 'Show PATH entries in order with existence check'
    for i in (seq (count $PATH))
        set -l dir $PATH[$i]
        if test -d "$dir"
            printf "%5d  %s\n" $i $dir
        else
            set_color red
            printf "%5d  %s (missing)\n" $i $dir
            set_color normal
        end
    end
end
