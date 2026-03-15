# ~/.config/fish/aliases.fish

# helper function for dynamic timer expansion
function __abbr_timer_minutes --argument token
    set -l minutes (string match -r --groups-only '^t([1-9][0-9]*)$' -- $token)
    or return 1
    printf 'timer %sm\n' "$minutes"
end

abbr -a t_num --regex '^t([1-9][0-9]*)$' --function __abbr_timer_minutes
abbr -a u 'update'
abbr -a t 'timer'
abbr -a vn 'vpn on'
abbr -a vf 'vpn off'
abbr -a vs 'vpn status'
abbr -a mn 'media on'
abbr -a mf 'media off'
abbr -a ff 'fastfetch'
abbr -a speed 'networkQuality'
abbr -a lg 'lazygit'
abbr -a mm 'mintmedia'
abbr -a m 'micro'
abbr -a gs 'git status'
abbr -a z 'cd'
abbr -a zl 'cdl'
abbr -a c 'bat'

alias batt='system_profiler SPPowerDataType | rg -i "cycle count|maximum capacity|condition"'
alias gt='timer 3m -q; and say "your tea is ready now"'
alias bt='timer 4m -q; and say "your tea is ready now"'
alias l='eza --git --group-directories-first'
alias lab='media on; and ssh lab'
