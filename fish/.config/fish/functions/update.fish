function update --description 'Update Homebrew formulae/casks and cleanup'
    if not command -q brew
        echo "update: brew not found; cannot continue" >&2
        return 127
    end

    brew update; or return 1
    brew upgrade; or return 1
    brew cleanup

    echo (set_color normal --bold)"Update complete 🎉"(set_color normal)
end
