function stow-remove --description 'Unstow a dotfiles package and move it back to ~/.config'
    if test (count $argv) -ne 1
        echo "stow-remove: usage - stow-remove <package> (e.g. stow-remove ghostty)" >&2
        return 1
    end

    set -l package $argv[1]
    set -l dotfiles $HOME/.dotfiles
    set -l src $dotfiles/$package/.config/$package
    set -l dest $HOME/.config/$package

    if not test -e $src
        echo "stow-remove: $src does not exist" >&2
        return 1
    end

    if test -e $dest
        echo "stow-remove: $dest already exists (is it already unstowed?)" >&2
        return 1
    end

    stow -Dvt $HOME -d $dotfiles $package
    mv $src $dest
    rm -rf $dotfiles/$package
end
