function gr --description 'Jump to a git repo root via fzf'
    # Base search dir(s) – add more paths as needed
    set -l roots ~/dev ~/.dotfiles
    set -l tab (printf '\t')

    # Dependency checks
    for tool in git fzf fd
        if not command -q $tool
            echo "gr: $tool not found" >&2
            return 127
        end
    end

    # Find repo roots by exact .git directory match
    set -l dirs (fd -L -H -t d '^\.git$' $roots 2>/dev/null | string replace '/.git' '' | sort)

    if test (count $dirs) -eq 0
        echo "gr: no git repos found under: $roots" >&2
        return 1
    end

    # Build menu: basename tab full path
    set -l menu
    for d in $dirs
        set menu $menu (string join "$tab" (path basename $d) "$d")
    end

    set -l choice (
        printf '%s\n' $menu | fzf \
            --prompt='gr> ' \
            --height=80% \
            --reverse \
            --delimiter="$tab" \
            --with-nth=1
    )

    if test -z "$choice"
        echo "gr: cancelled" >&2
        return 1
    end

    # Extract full path (second tab-delimited field)
    set -l target (string split "$tab" -- $choice)[2]

    if test -d "$target"
        cd "$target"
        zoxide add "$target"
    else
        echo "gr: target directory no longer exists: $target" >&2
        return 1
    end
end
