function fish_right_prompt
    if not set -q CMD_DURATION; or test $CMD_DURATION -le 3000
        return
    end
    set_color brblack
    if test $CMD_DURATION -ge 3600000
        set -l hours (math --scale=0 "$CMD_DURATION / 3600000")
        set -l mins (math --scale=0 "$CMD_DURATION % 3600000 / 60000")
        set -l secs (math --scale=0 "$CMD_DURATION % 60000 / 1000")
        echo -n $hours"h "$mins"m "$secs"s"
    else if test $CMD_DURATION -ge 60000
        set -l mins (math --scale=0 "$CMD_DURATION / 60000")
        set -l secs (math --scale=0 "$CMD_DURATION % 60000 / 1000")
        echo -n $mins"m "$secs"s"
    else
        set -l secs (math --scale=1 "$CMD_DURATION / 1000")
        echo -n $secs"s"
    end
    set_color normal
end
