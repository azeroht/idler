#!/bin/sh
# State file access for azeroht.idler, run in its own process so the shell
# never opens the file itself:
#   state.sh load <file>          print the file when it is a regular file
#                                 (no symlink, FIFO or device) of
#                                 MAXIMUM_BYTES at most; nothing if missing
#   state.sh save <file> <json>   write a private temporary file next to it,
#                                 then rename it over the path: a symlink
#                                 there is replaced, never followed
set -eu

# The state is about 120 bytes: anything larger is not ours.
MAXIMUM_BYTES=4096
# A file swapped for a FIFO after the checks would block the read forever.
READ_TIMEOUT_SECONDS=2

byte_count() {
  printf '%s' "$1" | LC_ALL=C wc -c
}

load() {
  file="$1"
  if [ ! -e "${file}" ] && [ ! -L "${file}" ]; then
    exit 0
  fi
  if [ -L "${file}" ] || [ ! -f "${file}" ]; then
    echo "state.sh: ${file} is not a regular file, ignored" >&2
    exit 1
  fi
  content="$(timeout "${READ_TIMEOUT_SECONDS}" head -c "$((MAXIMUM_BYTES + 1))" "${file}")" || exit 1
  if [ "$(byte_count "${content}")" -gt "${MAXIMUM_BYTES}" ]; then
    echo "state.sh: ${file} is larger than ${MAXIMUM_BYTES} bytes, ignored" >&2
    exit 1
  fi
  printf '%s\n' "${content}"
}

save() {
  file="$1"
  content="$2"
  [ "$(byte_count "${content}")" -le "${MAXIMUM_BYTES}" ] || exit 1
  mkdir -p "$(dirname "${file}")"
  temporary="$(mktemp "${file}.XXXXXX")"
  trap 'rm -f "${temporary}"' EXIT
  printf '%s\n' "${content}" >"${temporary}"
  # -T: a directory, or a symlink to one, at the path is never entered.
  mv -f -T "${temporary}" "${file}"
  trap - EXIT
}

case "${1:-}" in
  load)
    [ "$#" -eq 2 ] || exit 2
    load "$2"
    ;;
  save)
    [ "$#" -eq 3 ] || exit 2
    save "$2" "$3"
    ;;
  *)
    exit 2
    ;;
esac
