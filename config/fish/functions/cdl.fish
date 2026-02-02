function cdl --wraps=cd --description 'Change directory and list contents with eza'
    if test (count $argv) -gt 0
        # Change directory to the first argument
        cd "$argv[1]"
        # Run eza with the remaining arguments ($argv[2..-1])
        and eza -lh --git --group-directories-first --header $argv[2..-1]
    else
        # Default behavior: list current directory
        eza -lh --git --group-directories-first --header
    end
end