#!/opt/homebrew/bin/fish
# @raycast.schemaVersion 1
# @raycast.title Update Homebrew
# @raycast.mode fullOutput

brew update && brew upgrade --no-ask && brew cleanup
