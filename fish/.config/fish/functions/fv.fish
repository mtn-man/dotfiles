function fv --description 'Open file in vim via fd search (fzf when multiple matches)'
# Searches ~/dev and ~/.dotfiles together, then falls back to cwd if no matches
    for tool in fd fzf vim
        if not command -q $tool
            echo "fv: required tool missing: $tool" >&2
            return 1
        end
    end

    # Split vim flags (e.g. -y, +42) from the filename argument, regardless of position
    set -l vim_flags
    set -l query
    for arg in $argv
        if string match -qr '^[-+]' -- "$arg"
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
    set -l search_dirs ~/dev ~/.dotfiles

    # Search $search_dirs together
    set -l matches (fd $fd_opts "$query[1]" $search_dirs)

    # Fallback: search current working directory if no matches, unless cwd is
    # already inside one of $search_dirs (already covered by the search above)
    if test (count $matches) -eq 0
        set -l pwd_real (path resolve $PWD)
        set -l cwd_in_search_dirs 0
        for d in $search_dirs
            set -l d_real (path resolve $d)
            if test "$pwd_real" = "$d_real"; or string match -q -- "$d_real/*" "$pwd_real"
                set cwd_in_search_dirs 1
                break
            end
        end

        if test $cwd_in_search_dirs -eq 0
            echo "fv: no matches in $search_dirs, searching cwd..."
            set matches (fd $fd_opts "$query[1]" .)
        end
    end

    switch (count $matches)
        case 0
            echo "fv: no matches found"
            return 1

        case 1
            vim $vim_flags $matches
            return

        case '*'
            if not command -q bat
                echo "fv: bat required for preview (multiple matches found)" >&2
                return 1
            end

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
