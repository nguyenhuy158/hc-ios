#!/bin/sh
cat >/dev/null 2>&1
[ -n "${HC_TERMINAL_ID-}" ] || exit 0
case "$1" in
  blocked) extra=":kind=permission" ;;
  *) extra="" ;;
esac
pid=$PPID
tty=""
while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
  t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -n "$t" ] && [ "$t" != "??" ]; then
    tty="/dev/$t"
    break
  fi
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
[ -n "$tty" ] && [ -w "$tty" ] || exit 0
printf '\033]7501;state=%s:app=claude-code%s\033\\' "$1" "$extra" > "$tty" 2>/dev/null
exit 0
