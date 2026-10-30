#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

BUNDLE=dev.nguyenhuy158.hcios
HC="$HOME/.local/bin/herdr-core"
SESSION=hc-ios-e2e
SIM="${SIM:-iPhone 15}"
WORK=$(mktemp -d /tmp/hc-ios-e2e.XXXXXX)
WRAP="$WORK/hc"
DEST="platform=iOS Simulator,name=$SIM"

hc() { HC_SESSION=$SESSION "$HC" "$@"; }

cleanup() {
  python3 scripts/e2e-keys.py remove || true
  hc kill e2e-blocked >/dev/null 2>&1 || true
  hc kill e2e-working >/dev/null 2>&1 || true
  hc server stop >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

printf '#!/bin/sh\nHC_SESSION=%s exec "%s" "$@"\n' "$SESSION" "$HC" > "$WRAP"
chmod +x "$WRAP"

hc run --bg --name e2e-blocked python3 "$PWD/scripts/fake-agent.py" blocked >/dev/null
hc run --bg --name e2e-working python3 "$PWD/scripts/fake-agent.py" working >/dev/null

xcodegen generate
xcodebuild -project HcIOS.xcodeproj -scheme HcIOS -destination "$DEST" -derivedDataPath build -onlyUsePackageVersionsFromResolvedFile build-for-testing -quiet

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/HcIOS.app
xcrun simctl launch --terminate-running-process booted "$BUNDLE" -uiTestingNoLock >/dev/null
sleep 3
PREFS="$(xcrun simctl get_app_container booted "$BUNDLE" data)/Library/Preferences/$BUNDLE"
KEY=$(xcrun simctl spawn booted defaults read "$PREFS" publicKey)
xcrun simctl terminate booted "$BUNDLE" 2>/dev/null || true
xcrun simctl spawn booted defaults delete "$PREFS" trustedHostKeys 2>/dev/null || true
python3 scripts/e2e-keys.py add "$KEY"

FINGERPRINT=$(ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub | awk '{print $2}')

TEST_RUNNER_E2E_USER="$(whoami)" \
TEST_RUNNER_E2E_HC="$WRAP" \
TEST_RUNNER_E2E_FINGERPRINT="$FINGERPRINT" \
xcodebuild -project HcIOS.xcodeproj -scheme HcIOS -destination "$DEST" -derivedDataPath build \
  test-without-building -only-testing:HcIOSUITests
