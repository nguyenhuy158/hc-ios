#!/bin/sh
set -eu
bundle=dev.nguyenhuy158.hcios
out=${1:-docs/mock}
scenarios="list many loading empty disconnected detail detailWorking detailLong settings settingsFailed firstLaunch hostKey hostKeyChanged lock"
mkdir -p "$out"
xcrun simctl status_bar booted override --time 9:41 --batteryLevel 100 --cellularBars 4 --wifiBars 3
for mode in light dark; do
  xcrun simctl ui booted appearance "$mode"
  for s in $scenarios; do
    xcrun simctl launch --terminate-running-process booted "$bundle" -mock "$s" >/dev/null
    sleep 2
    xcrun simctl io booted screenshot "$out/$s-$mode.png" >/dev/null 2>&1
    echo "$out/$s-$mode.png"
  done
done
xcrun simctl ui booted appearance light
