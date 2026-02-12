function fdm --description 'Open file in micro via fd search (fzf when multiple matches)'
    if test (count $argv) -eq 0
        echo "Usage: fdm <pattern>"
        return 1
    end

    # Find matches under ~/dev (follow symlinks, include hidden)
    set -l matches (fd -L -H -t f -g "*$argv[1]*" ~/dev)

    switch (count $matches)
        case 0
            echo "fdm: no matches found"
            return 1

        case 1
            micro $matches[1]
            return 0

        case '*'
            # Pick one (or many) interactively
            set -l chosen (printf '%s\n' $matches | fzf -i --prompt='fdm> ')

            if test (count $chosen) -eq 0
                echo "fdm: cancelled"
                return 1
            end

            # fzf returns newline-separated paths; fish splits them into a list automatically
            micro $chosen
    end
end
