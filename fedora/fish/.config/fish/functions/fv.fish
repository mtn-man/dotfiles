function fv --description 'Open file in vim via fd search (fzf when multiple matches)'
# Searches ~/dev and ~/.dotfiles together, then falls back to cwd if no matches
    for tool in fd fzf vim bat
        if not command -q $tool
            echo "fv: required tool missing: $tool" >&2
            return 1
        end
    end

    # Split leading vim flags (e.g. -y, +42) from the filename argument
    set -l vim_flags
    set -l query
    for arg in $argv
        if test -z "$query" -a \( (string sub -l 1 -- "$arg") = "-" -o (string sub -l 1 -- "$arg") = "+" \)
            set vim_flags $vim_flags $arg
        else
            set query $query $arg
        end
    end

    if test (count $query) -ne 1
        echo "fv: usage - fv [vim flags] <filename> (e.g. fv -y snap.fish)" >&2
        return 1
    end

    # Common fd options
    set -l fd_opts --no-ignore -L -H -t f --exclude .git

    # Search ~/dev and ~/.dotfiles together
    set -l matches (fd $fd_opts "$query[1]" ~/dev ~/.dotfiles)

    # Fallback: search current working directory if no matches
    if test (count $matches) -eq 0
        echo "fv: no matches in ~/dev or ~/.dotfiles, searching cwd..."
        set matches (fd $fd_opts "$query[1]" .)
    end

    switch (count $matches)
        case 0
            echo "fv: no matches found"
            return 1

        case 1
            vim $vim_flags $matches
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

            vim $vim_flags $chosen
            return
    end
end
