function fm --description 'Open file in micro via fd search (fzf when multiple matches)'
# Always searches ~/dev first, then falls back to cwd if no matches (by design)
    if test (count $argv) -eq 0
        echo "Usage: fm <pattern>"
        return 1
    end

    # Common fd options
    set -l fd_opts --no-ignore -L -H -t f --exclude .git

    # Search under ~/dev
    set -l matches (fd $fd_opts "$argv[1]" ~/dev)

    # Fallback: search current working directory if no matches
    if test (count $matches) -eq 0
        set matches (fd $fd_opts "$argv[1]" .)
    end

    switch (count $matches)
        case 0
            echo "fm: no matches found"
            return 1

        case 1
            micro $matches[1]
            return 0

        case '*'
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
