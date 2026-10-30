#!/bin/sh
cat >/dev/null 2>&1
[ -n "${HC_TERMINAL_ID-}" ] || exit 0
case "$1" in
  blocked) extra=":kind=permission" ;;
  *) extra="" ;;
esac
printf '\033]7501;state=%s:app=claude-code%s\033\\' "$1" "$extra" > /dev/tty 2>/dev/null
exit 0
