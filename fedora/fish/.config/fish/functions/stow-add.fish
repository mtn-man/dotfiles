function stow-add --description 'Move a ~/.config package into dotfiles and stow it'
    if test (count $argv) -ne 1
        echo "stow-add: usage - stow-add <package> (e.g. stow-add ghostty)" >&2
        return 1
    end

    set -l package $argv[1]
    set -l dotfiles $HOME/dev/dotfiles/fedora
    set -l src $HOME/.config/$package
    set -l dest $dotfiles/$package/.config/$package

    if not test -e $src
        echo "stow-add: $src does not exist" >&2
        return 1
    end

    if test -e $dest
        echo "stow-add: $dest already exists" >&2
        return 1
    end

    mkdir -p $dotfiles/$package/.config
    mv $src $dest

    stow -vt $HOME -d $dotfiles $package
end
