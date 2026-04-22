function fish_right_prompt
  if not set -q CMD_DURATION; or test $CMD_DURATION -le 3000
      return
  end
  set -l secs (math "$CMD_DURATION / 1000")
  set_color brblack
  echo -n "$secs"s
  set_color normal
end
