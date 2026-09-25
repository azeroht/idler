#!/bin/sh
# One activity pulse for azeroht.idler:
#   idler.sh key <keysym>   press and release the key (wtype)
#   idler.sh mouse          nudge the cursor one pixel right, then back
set -eu

# Moves the cursor by $1 pixels on x, from its current position.
# hyprctl cursorpos prints "x, y" in global, integer coordinates.
nudge() {
  position="$(hyprctl cursorpos)"
  x="${position%%,*}"
  y="${position##*, }"
  case "${x}${y}" in
    '' | *[!0-9-]*) exit 1 ;;
  esac
  hyprctl dispatch "hl.dsp.cursor.move({ x = $((x + $1)), y = ${y} })" >/dev/null
}

case "${1:-}" in
  key)
    keysym="${2:-}"
    case "${keysym}" in
      '' | *[!A-Za-z0-9_]*) exit 1 ;;
    esac
    exec wtype -k "${keysym}"
    ;;
  mouse)
    # The way back is read again after the pause: a move made by the user in
    # between is kept, only the added pixel is taken away.
    nudge 1
    sleep 0.05
    nudge -1
    ;;
  *)
    exit 2
    ;;
esac
