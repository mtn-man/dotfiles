#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Open lf in YouTube
# @raycast.mode silent

open -na Ghostty.app --args \
  --window-save-state=never \
  "--working-directory=$HOME/Movies/YouTube" \
  -e /opt/homebrew/bin/fish -C lf
