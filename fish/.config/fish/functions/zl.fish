function zl --wraps=cd --description 'Change directory (zoxide) and list contents with eza'
    if test (count $argv) -gt 0
        z "$argv[1]"; or return 1
        eza --git --group-directories-first $argv[2..-1]
    else
        z; or return 1
        eza --git --group-directories-first
    end
end
