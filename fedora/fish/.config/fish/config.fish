set -gx EDITOR "micro"
set -g  HOMELAB "100.106.45.25"
set -g  HOMELAB_LOCAL "192.168.0.43"
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

fish_add_path -gP ~/.local/bin
fish_add_path -gP ~/.cargo/bin
fish_add_path -gP ~/go/bin

if status is-interactive
    source ~/.config/fish/abbrs.fish
    command -q zoxide; and zoxide init fish --cmd cd | source
end
