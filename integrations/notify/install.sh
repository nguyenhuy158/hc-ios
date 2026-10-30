#!/bin/sh
set -eu
LABEL=dev.nguyenhuy158.hc-notify
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DIR="$HOME/.config/hc-notify"
SCRIPT="$(cd "$(dirname "$0")" && pwd)/hc-notify.py"

if [ "${1-}" = "--uninstall" ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "hc-notify removed (topic kept in $DIR/topic)"
  exit 0
fi

mkdir -p "$DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
chmod 700 "$DIR"
if [ ! -s "$DIR/topic" ]; then
  python3 -c "import secrets,string;a=string.ascii_letters+string.digits;print('hc-'+''.join(secrets.choice(a) for _ in range(32)))" > "$DIR/topic"
  chmod 600 "$DIR/topic"
fi

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/usr/bin/python3</string><string>$SCRIPT</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/hc-notify.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/hc-notify.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "hc-notify running. Subscribe in the ntfy iPhone app to: $(cat "$DIR/topic")"
