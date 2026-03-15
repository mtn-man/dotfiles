function gr --description 'Jump to a git repo root via fzf'
    # Base search dir(s) – add more paths as needed
    set -l roots ~/dev
    set -l tab (printf '\t')

    # Dependency checks
    if not command -q git
        echo "gr: git not found" >&2
        return 127
    end
    if not command -q eza
        echo "gr: eza not found" >&2
        return 127
    end
    if not command -q fzf
        echo "gr: fzf not found (brew install fzf)" >&2
        return 127
    end
    if not command -q fd
        echo "gr: fd not found (brew install fd)" >&2
        return 127
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
        set menu $menu (string join "$tab" (basename "$d") "$d")
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
        eza -aTL3 --git-ignore
        zoxide add "$target"
    else
        echo "gr: target directory no longer exists: $target" >&2
        return 1
    end
end
