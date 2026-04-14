function fish_right_prompt
  if test $CMD_DURATION -gt 3000
      set -l secs (math "$CMD_DURATION / 1000")
      set_color brblack
      echo -n "$secs"s
      set_color normal
  end
end
