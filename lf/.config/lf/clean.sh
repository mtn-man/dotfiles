#!/bin/sh
# Prefer kitten clear for reliable cleanup in kitty-graphics terminals.
if command -v kitten >/dev/null 2>&1; then
    kitten icat --clear --stdin=no --silent --transfer-mode=file < /dev/null > /dev/tty 2>/dev/null || true
    exit 0
fi

# Fallback kitty-graphics clear escape if kitten is unavailable.
printf '\033_Ga=d,d=A\033\\' > /dev/tty 2>/dev/null || true
exit 0
