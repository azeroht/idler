#!/usr/bin/env bash
# Tests for idler.sh. wtype and hyprctl are replaced by stubs that record
# their arguments, so the tests run anywhere: no Wayland session, no
# Hyprland, and the real cursor never moves.
#
# Usage: tests/idler.test.sh   (or "make test")

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/idler.sh"
STUBS="$(mktemp -d)"
LOG="$STUBS/calls.log"
trap 'rm -rf "$STUBS"' EXIT
failures=0

# hyprctl stub: "cursorpos" answers the position in $STUBS/position, and
# "dispatch" applies the move to it, like Hyprland would.
cat >"$STUBS/hyprctl" <<'EOF'
#!/bin/sh
directory="$(dirname "$0")"
echo "hyprctl $*" >>"$directory/calls.log"
case "$1" in
  cursorpos) cat "$directory/position" ;;
  dispatch)
    x=$(printf '%s' "$2" | sed -n 's/.*x = \(-\{0,1\}[0-9]*\).*/\1/p')
    y=$(printf '%s' "$2" | sed -n 's/.*y = \(-\{0,1\}[0-9]*\).*/\1/p')
    printf '%s, %s\n' "$x" "$y" >"$directory/position"
    echo ok
    ;;
esac
EOF
printf '#!/bin/sh\necho "wtype $*" >>"$(dirname "$0")/calls.log"\n' >"$STUBS/wtype"
chmod +x "$STUBS/hyprctl" "$STUBS/wtype"
export PATH="$STUBS:$PATH"

reset_stubs() {
  : >"$LOG"
  printf '%s\n' "$1" >"$STUBS/position"
}

expect() {
  local label="$1" actual="$2" wanted="$3"
  if [ "$actual" = "$wanted" ]; then
    printf '  ok    %-44s [%s]\n' "$label" "$actual"
  else
    printf '  FAIL  %-44s [%s], wanted [%s]\n' "$label" "$actual" "$wanted"
    failures=$((failures + 1))
  fi
}

echo "idler.sh key"
reset_stubs "0, 0"
"$SCRIPT" key F15
expect "exit code" "$?" "0"
expect "presses the key with wtype" "$(cat "$LOG")" "wtype -k F15"

reset_stubs "0, 0"
"$SCRIPT" key F15 0
expect "a zero hold is a plain tap" "$(cat "$LOG")" "wtype -k F15"

reset_stubs "0, 0"
"$SCRIPT" key Shift_L 500
expect "exit code with a hold" "$?" "0"
expect "holds the key, then releases it" "$(cat "$LOG")" "wtype -P Shift_L -s 500 -p Shift_L"

reset_stubs "0, 0"
"$SCRIPT" key F15 10000
expect "accepts the maximum hold" "$(cat "$LOG")" "wtype -P F15 -s 10000 -p F15"

for hold in '10001' '-1' '5;id' '1.5' ''; do
  reset_stubs "0, 0"
  "$SCRIPT" key F15 "$hold"
  expect "refuses invalid hold [$hold]" "$?" "1"
  expect "  and runs nothing" "$(cat "$LOG")" ""
done

for keysym in 'F15;rm' '-k' 'F 15' '$(id)' ''; do
  reset_stubs "0, 0"
  "$SCRIPT" key "$keysym"
  expect "refuses unsafe keysym [$keysym]" "$?" "1"
  expect "  and runs nothing" "$(cat "$LOG")" ""
done

echo "idler.sh mouse"
reset_stubs "955, 2382"
"$SCRIPT" mouse
expect "exit code" "$?" "0"
expect "moves one pixel right" "$(sed -n 2p "$LOG")" "hyprctl dispatch hl.dsp.cursor.move({ x = 956, y = 2382 })"
expect "then one pixel left" "$(sed -n 4p "$LOG")" "hyprctl dispatch hl.dsp.cursor.move({ x = 955, y = 2382 })"
expect "ends where it started" "$(cat "$STUBS/position")" "955, 2382"

reset_stubs "not a position"
"$SCRIPT" mouse
expect "refuses a malformed position" "$?" "1"
expect "  and never moves the cursor" "$(grep -c dispatch "$LOG")" "0"

echo "idler.sh usage"
"$SCRIPT" >/dev/null 2>&1
expect "no action: exit code 2" "$?" "2"
"$SCRIPT" jump >/dev/null 2>&1
expect "unknown action: exit code 2" "$?" "2"

echo
if [ "$failures" -eq 0 ]; then
  echo "idler.sh: all tests pass"
else
  echo "idler.sh: $failures failure(s)"
  exit 1
fi
