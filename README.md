# hc-ios

<img src="docs/icon/b1.png" width="96" align="right">

iPhone app to watch and steer coding agents running in [herdr-core](https://github.com/herdrdev/herdr-app) (`hc`) on your Mac, over SSH. It lists every terminal (including other machines added with `hc machine add`), puts the ones that need you on top, shows their screen and lets you answer them.

The phone runs `hc connect` over SSH and speaks hc's JSON-RPC directly: no relay, no server, no account.

## Requirements

- iPhone on iOS 17 or later
- A Mac with Xcode 15.4+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- herdr-core on the Mac (`~/.local/bin/herdr-core`, installed with the [Herdr app](https://github.com/herdrdev/herdr-app))
- Mac and iPhone on the same [Tailscale](https://tailscale.com) network

## Mac setup

1. Turn on **System Settings → General → Sharing → Remote Login**.
2. Find the Mac's Tailscale name: `tailscale status --self` (for example `macbook.tailnet.ts.net`).

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

`xcrun devicectl list devices` shows the device id. The first time, trust the developer on the phone: **Settings → General → VPN & Device Management**.

## First run

1. Unlock with Face ID.
2. In **Settings** fill in host (Tailscale name), user and the hc path.
3. **Copy public key** and add it on the Mac: `echo '<key>' >> ~/.ssh/authorized_keys`.
4. Tap **Done**. Compare the fingerprint with `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` and tap **Trust**.

The private key is generated on the phone and stays in its Keychain (this device only). The Mac's host key is pinned on first use; a changed key is refused until you trust it again.

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
