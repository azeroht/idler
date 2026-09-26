#!/usr/bin/env bash
# Tests for state.sh, in a throwaway directory: no real state file is read
# or written.
#
# Usage: tests/state.test.sh   (or "make test")

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/state.sh"
WORK="$(mktemp -d)"
FILE="$WORK/state.json"
OUTSIDE="$WORK/outside.json"
STATE='{"enabled":true,"action":"F15"}'
MAXIMUM_BYTES=4096
trap 'rm -rf "$WORK"' EXIT
failures=0

reset_work() {
  rm -rf "${WORK:?}"/*
}

expect() {
  local label="$1" actual="$2" wanted="$3"
  if [ "$actual" = "$wanted" ]; then
    printf '  ok    %-48s [%s]\n' "$label" "$actual"
  else
    printf '  FAIL  %-48s [%s], wanted [%s]\n' "$label" "$actual" "$wanted"
    failures=$((failures + 1))
  fi
}

echo "state.sh load"
reset_work
printf '%s\n' "$STATE" >"$FILE"
expect "prints a regular file" "$("$SCRIPT" load "$FILE")" "$STATE"

reset_work
expect "a missing file prints nothing" "$("$SCRIPT" load "$FILE")" ""
"$SCRIPT" load "$FILE"
expect "  and succeeds" "$?" "0"

reset_work
printf '%s\n' "$STATE" >"$OUTSIDE"
ln -s "$OUTSIDE" "$FILE"
expect "refuses a symlink" "$("$SCRIPT" load "$FILE" 2>/dev/null)" ""
"$SCRIPT" load "$FILE" 2>/dev/null
expect "  with exit code 1" "$?" "1"

reset_work
ln -s "$WORK/nowhere" "$FILE"
"$SCRIPT" load "$FILE" 2>/dev/null
expect "refuses a dangling symlink" "$?" "1"

reset_work
mkfifo "$FILE"
"$SCRIPT" load "$FILE" 2>/dev/null
expect "refuses a FIFO without blocking" "$?" "1"

reset_work
mkdir "$FILE"
"$SCRIPT" load "$FILE" 2>/dev/null
expect "refuses a directory" "$?" "1"

reset_work
head -c "$((MAXIMUM_BYTES + 1))" /dev/zero | tr '\0' 'x' >"$FILE"
expect "refuses a file over the size limit" "$("$SCRIPT" load "$FILE" 2>/dev/null)" ""
"$SCRIPT" load "$FILE" 2>/dev/null
expect "  with exit code 1" "$?" "1"

reset_work
head -c "$MAXIMUM_BYTES" /dev/zero | tr '\0' 'x' >"$FILE"
expect "accepts a file at the size limit" "$("$SCRIPT" load "$FILE" | wc -c | tr -d ' ')" "$((MAXIMUM_BYTES + 1))"

echo "state.sh save"
reset_work
"$SCRIPT" save "$FILE" "$STATE"
expect "exit code" "$?" "0"
expect "writes the state" "$(cat "$FILE")" "$STATE"
expect "leaves no temporary file" "$(ls "$WORK")" "state.json"

reset_work
printf '%s\n' "old" >"$OUTSIDE"
ln -s "$OUTSIDE" "$FILE"
"$SCRIPT" save "$FILE" "$STATE"
expect "replaces a symlink instead of following it" "$(cat "$OUTSIDE")" "old"
expect "  with a regular file" "$([ -f "$FILE" ] && [ ! -L "$FILE" ] && echo regular)" "regular"

reset_work
mkdir "$WORK/target"
ln -s "$WORK/target" "$FILE"
"$SCRIPT" save "$FILE" "$STATE" 2>/dev/null
expect "never writes into a linked directory" "$(ls "$WORK/target")" ""

reset_work
mkdir "$FILE"
"$SCRIPT" save "$FILE" "$STATE" 2>/dev/null
expect "refuses a directory at the path" "$?" "1"
expect "  and leaves no temporary file" "$(ls "$WORK")" "state.json"

reset_work
"$SCRIPT" save "$FILE" "$(head -c "$((MAXIMUM_BYTES + 1))" /dev/zero | tr '\0' 'x')"
expect "refuses a state over the size limit" "$?" "1"
expect "  and writes nothing" "$(ls "$WORK")" ""

reset_work
"$SCRIPT" save "$WORK/new/state.json" "$STATE"
expect "creates a missing directory" "$(cat "$WORK/new/state.json")" "$STATE"

echo "state.sh usage"
"$SCRIPT" >/dev/null 2>&1
expect "no action: exit code 2" "$?" "2"
"$SCRIPT" load >/dev/null 2>&1
expect "load without a file: exit code 2" "$?" "2"
"$SCRIPT" save "$FILE" >/dev/null 2>&1
expect "save without a state: exit code 2" "$?" "2"

echo
if [ "$failures" -eq 0 ]; then
  echo "state.sh: all tests pass"
else
  echo "state.sh: $failures failure(s)"
  exit 1
fi
