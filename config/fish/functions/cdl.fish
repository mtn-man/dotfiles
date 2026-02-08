function cdl --wraps=cd --description 'Change directory and list contents with eza'
    if test (count $argv) -gt 0
        cd "$argv[1]"
        and eza --git --group-directories-first --header $argv[2..-1]
    else
        cd
        and eza --git --group-directories-first --header
    end
end
