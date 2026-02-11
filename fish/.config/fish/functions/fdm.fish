function fdm --description 'Open file in micro via fd search'
   if test (count $argv) -eq 0
        echo "Usage: mf <pattern>"
        return 1
    end

    # Use glob matching so you don’t need to escape dots
    set -l matches (fd -L -t f -g "$argv[1]" ~/dev)

    if test (count $matches) -eq 0
        echo "mf: no matches found"
        return 1
    end

    # If one or more matches exist, open them in micro
    micro $matches
end
