#!/bin/sh
# One activity pulse for azeroht.idler:
#   idler.sh key <keysym> [hold]   press the key, hold it <hold> ms (0 by
#                                  default), then release it (wtype)
#   idler.sh mouse                 nudge the cursor one pixel right, then back
set -eu

# Same ceiling as MAXIMUM_HOLD_MILLISECONDS in Model.js.
MAXIMUM_HOLD=10000

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
    hold="${3-0}"
    case "${keysym}" in
      '' | *[!A-Za-z0-9_]*) exit 1 ;;
    esac
    case "${hold}" in
      '' | *[!0-9]*) exit 1 ;;
    esac
    [ "${hold}" -le "${MAXIMUM_HOLD}" ] || exit 1
    if [ "${hold}" -eq 0 ]; then
      exec wtype -k "${keysym}"
    fi
    exec wtype -P "${keysym}" -s "${hold}" -p "${keysym}"
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
