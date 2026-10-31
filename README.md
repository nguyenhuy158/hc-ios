# hc-ios

<img src="docs/icon/b1.png" width="96" align="right">

iPhone app to watch and steer coding agents running in [herdr-core](https://github.com/herdrdev/herdr-app) (`hc`) on your Mac, over SSH. It lists every terminal (including other machines added with `hc machine add`), puts the ones that need you on top, shows their screen and lets you answer them.

The phone runs `hc connect` over SSH and speaks hc's JSON-RPC directly: no relay, no server, no account.

## Requirements

- iPhone on iOS 17 or later
- A Mac with Xcode 15.4+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- herdr-core on the Mac (`~/.local/bin/herdr-core`, installed with the [Herdr app](https://github.com/herdrdev/herdr-app))
- Mac and iPhone on the same [Tailscale](https://tailscale.com) network
- `qrencode` on the Mac for pairing (`brew install qrencode`)

## Mac setup

Turn on **System Settings → General → Sharing → Remote Login**.

## Build

```sh
make build        # simulator build
make sim          # build and run on the iPhone 15 simulator
make shots        # screenshot every mock state, light and dark, into docs/mock
```

On a real iPhone (free Apple ID works; the app then expires after 7 days):

```sh
xcodegen generate
xcodebuild -project HcIOS.xcodeproj -scheme HcIOS -destination 'id=<device id>' \
  -derivedDataPath build DEVELOPMENT_TEAM=<team id> -allowProvisioningUpdates build
xcrun devicectl device install app --device <device id> build/Build/Products/Debug-iphoneos/HcIOS.app
```

To avoid reinstalling from Xcode every 7 days, install [SideStore](https://sidestore.io) (nightly on iOS 26.4+) with [iloader](https://iloader.app), then build an unsigned IPA with `make ipa` and open `build/HcIOS.ipa` in SideStore; it re-signs hc on the phone.

Every push to `main` that touches the app builds a new IPA on GitHub Actions and publishes it with a SideStore source. Add it once in SideStore → Sources: `https://github.com/nguyenhuy158/hc-ios/releases/download/latest/source.json`. New builds then show up as updates (tap Update with LocalDevVPN connected).

`xcrun devicectl list devices` shows the device id. The first time, trust the developer on the phone: **Settings → General → VPN & Device Management**.

## First run

1. On the Mac run `make pair` (or `integrations/pair/hc-pair.py`). It prints a QR code.
2. Scan it with the iPhone Camera and open it in hc.

The app asks for confirmation, then fills in the Mac's Tailscale IP, user and hc path, pins the host key from the QR, sends its public key to the Mac (added to `~/.ssh/authorized_keys`) and connects. The pairing listener is a plain TCP socket on the Mac's Tailscale IP, needs the one-time token from the QR and stops after one pairing or 5 minutes. The IP is used instead of the MagicDNS name so pairing works without Tailscale DNS; run `make pair` again if the Mac's Tailscale IP changes.

Manual setup still works: fill in **Settings**, add the copied public key to `~/.ssh/authorized_keys`, tap **Done** and **Trust** the fingerprint shown by `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`.

The private key is generated on the phone and stays in its Keychain (this device only). A changed host key is refused until you trust it again.

## Agent status

hc only knows an agent is working, blocked or done when the program reports it with OSC 7501 (`ESC ] 7501 ; state=blocked:app=claude-code ESC \`). Programs that don't report show as **Idle**.

## Mock mode

Launch with `-mock <scenario>` to open a state with fake data: `list`, `many`, `loading`, `empty`, `disconnected`, `detail`, `detailWorking`, `detailLong`, `settings`, `settingsFailed`, `firstLaunch`, `hostKey`, `hostKeyChanged`, `lock`. Screens are in [`docs/mock`](docs/mock).

## Layout

| Path | What |
|---|---|
| `HcIOS/Client` | SSH (Citadel), JSON-RPC link, hc models, key and host-key storage, mock client |
| `HcIOS/App` | App state and mock scenarios |
| `HcIOS/Views` | SwiftUI screens |
| `docs/icon` | Icon options and sources |
