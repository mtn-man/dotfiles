# 1. Launch Wayland compositor on login
if status is-login
    if test (tty) = /dev/tty1
        set -gx QT_QPA_PLATFORM wayland
        set -gx MOZ_ENABLE_WAYLAND 1
        exec sway
    end
end

# 2. Environment Variables
set -gx EDITOR "micro"
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

# 3. PATH
fish_add_path -gP ~/.local/bin
fish_add_path -gP ~/.cargo/bin
fish_add_path -gP ~/go/bin

# 4. Interactive Session Configuration
if status is-interactive
    source ~/.config/fish/abbrs.fish
    # zoxide init
    command -q zoxide; and zoxide init fish --cmd cd | source
end
