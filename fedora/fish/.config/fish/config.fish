set -gx EDITOR "vim"
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
# Host-specific secrets/IPs (gitignored, not tracked) — see env.fish.example
if test -f ~/.config/fish/env.fish
    source ~/.config/fish/env.fish
end

fish_add_path -gP ~/.local/bin
fish_add_path -gP ~/.cargo/bin
fish_add_path -gP ~/go/bin

if status is-interactive
    source ~/.config/fish/abbrs.fish
    command -q zoxide; and zoxide init fish --cmd cd | source
end
