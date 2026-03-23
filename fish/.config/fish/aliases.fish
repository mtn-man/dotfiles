# ~/.config/fish/aliases.fish

# helper function for dynamic timer expansion
function __abbr_timer_minutes --argument token
    set -l minutes (string match -r --groups-only '^a([1-9][0-9]*)$' -- $token)
    or return 1
    printf 'after %sm\n' "$minutes"
end

abbr -a a_num --regex '^a([1-9][0-9]*)$' --function __abbr_timer_minutes
abbr -a u 'update'
abbr -a a 'after'
abbr -a vn 'vpn on'
abbr -a vf 'vpn off'
abbr -a vs 'vpn status'
abbr -a mn 'media on'
abbr -a mf 'media off'
abbr -a ms 'media status'
abbr -a ff 'fastfetch'
abbr -a speed 'networkQuality'
abbr -a lg 'lazygit'
abbr -a mm 'mintmedia'
abbr -a m 'micro'
abbr -a gs 'git status'
abbr -a z 'cd'
abbr -a zl 'cdl'
abbr -a c 'bat'
abbr -a envs 'env | sort | fzf'

alias batt='system_profiler SPPowerDataType | rg -i "cycle count|maximum capacity|condition"'
alias gt='after -q 3m; and say "your tea is ready now"'
alias bt='after -q 4m; and say "your tea is ready now"'
alias l='eza --git --group-directories-first'
alias lab='media on; and ssh lab'
