#!/opt/homebrew/bin/fish
# @raycast.schemaVersion 1
# @raycast.title Open Devbox
# @raycast.mode silent

open -na Ghostty.app --args \
  --window-save-state=never \
  -e ssh -t lab "podman exec -it -w /home/dev/dev/ devbox bash"
