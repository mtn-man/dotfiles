function fv --description 'Open file in vim via fd search (fzf when multiple matches)'
# Searches ~/dev and ~/.dotfiles together, then falls back to cwd if no matches
    for tool in fd fzf vim bat
        if not command -q $tool
            echo "fv: required tool missing: $tool" >&2
            return 1
        end
    end

    if test (count $argv) -ne 1
        echo "fv: usage - fv <filename> (e.g. fv config.fish)" >&2
        return 1
    end

    # Common fd options
    set -l fd_opts --no-ignore -L -H -t f --exclude .git

    # Search ~/dev and ~/.dotfiles together
    set -l matches (fd $fd_opts "$argv[1]" ~/dev ~/.dotfiles)

    # Fallback: search current working directory if no matches
    if test (count $matches) -eq 0
        echo "fv: no matches in ~/dev or ~/.dotfiles, searching cwd..."
        set matches (fd $fd_opts "$argv[1]" .)
    end

    switch (count $matches)
        case 0
            echo "fv: no matches found"
            return 1

        case 1
            vim $matches
            return

        case '*'
            set -l chosen (printf '%s\n' $matches | fzf -i \
                --prompt='fv> ' \
                --preview='bat --color=always --style=plain --theme="ansi" {}' \
                --preview-window='right:60%:wrap')

            if test -z "$chosen"
                echo "fv: cancelled"
                return 1
            end

            vim $chosen
            return
    end
end
