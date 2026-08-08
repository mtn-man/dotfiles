function stow-remove --description 'Unstow a dotfiles package and move it back to ~/.config'
    if test (count $argv) -ne 1
        echo "stow-remove: usage - stow-remove <package> (e.g. stow-remove ghostty)" >&2
        return 1
    end

    set -l package $argv[1]
    set -l dotfiles $HOME/.dotfiles/fedora
    set -l src $dotfiles/$package/.config/$package
    set -l dest $HOME/.config/$package

    if not test -e $src
        echo "stow-remove: $src does not exist" >&2
        return 1
    end

    if test -d $dest && not test -L $dest
        echo "stow-remove: $dest already exists (is it already unstowed?)" >&2
        return 1
    end

    stow -Dvt $HOME -d $dotfiles $package
    if not mv $src $dest
        echo "stow-remove: mv failed, leaving $dotfiles/$package intact" >&2
        return 1
    end
    rm -rf $dotfiles/$package

    # Keep stow-packages (fedora-bootstrap's shared package list) in sync so
    # removed packages don't linger there by hand.
    set -l pkglist $dotfiles/stow-packages
    if test -f $pkglist
        set -l tmp (mktemp)
        grep -vxF -- $package $pkglist > $tmp
        mv $tmp $pkglist
    end
end
