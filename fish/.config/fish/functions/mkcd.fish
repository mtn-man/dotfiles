function mkcd --description 'Create a directory and cd into it'
    if test (count $argv) -lt 1
        echo "mkcd: usage - mkcd <directory> (e.g. mkcd src)" >&2
        return 1
    end

    mkdir -p "$argv[1]"
    and cd "$argv[1]"
end
