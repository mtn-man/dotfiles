function fm --description 'Open file in micro via fd search (fzf when multiple matches)'
    if test (count $argv) -eq 0
        echo "Usage: fm <pattern>"
        return 1
    end

    # Find matches under ~/dev (follow symlinks, include hidden)
    set -l matches (fd --no-ignore -L -H -t f -g "*$argv[1]*" ~/dev)
    
    # Fallback: if nothing found, search current working directory
    if test (count $matches) -eq 0
        set matches (fd --no-ignore -L -H -t f -g "*$argv[1]*" .)
    end
    
    switch (count $matches)
        case 0
            echo "fm: no matches found"
            return 1

        case 1
            micro $matches[1]
            return 0

        case '*'
            # Pick one interactively with preview
            set -l chosen (printf '%s\n' $matches | fzf -i \
                 --prompt='fm> ' \
                 --preview='bat --color=always --style=plain --theme="ansi" {}' \
                 --preview-window='right:60%:wrap')

            if test (count $chosen) -eq 0
                echo "fm: cancelled"
                return 1
            end

            micro $chosen
    end
end
