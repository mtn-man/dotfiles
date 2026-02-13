function lp --description 'Show PATH entries in order'
    for i in (seq (count $PATH))
        printf "%5d  %s\n" $i $PATH[$i]
    end
end
