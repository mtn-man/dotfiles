function cdl --wraps=cd --description 'Change directory (zoxide) and list contents with eza'
    if test (count $argv) -gt 0
        cd "$argv[1]"; or return 1
        eza --git --group-directories-first $argv[2..-1]
    else
        cd; or return 1
        eza --git --group-directories-first
    end
end
