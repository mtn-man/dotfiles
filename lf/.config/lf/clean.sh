#!/bin/sh
# Clear any images at the location using kitty icat's clear flag
kitty +kitten icat --clear --stdin=no --silent --transfer-mode=file < /dev/null > /dev/tty
