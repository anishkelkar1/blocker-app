# FocusLock

A personal focus app for iPhone that blocks distracting apps and websites,
with a strict "commitment" mode. Built on Apple's **Screen Time API**
(`FamilyControls` + `ManagedSettings` + `DeviceActivity`) — no MITM proxy, no
root helper, no VPN.

> Personal project. Not for the App Store.

## Features

- **Block apps, categories and websites** using the system `FamilyActivityPicker`.
- **Timed focus sessions** or block-until-you-stop.
- **Strict mode**, three levels:
  - *Off* — stop anytime.
  - *PIN required* — stopping a block needs your PIN.
  - *Locked until timer* — a timed session can't be stopped early, PIN included.
- **"Can't delete" lock** — sets ManagedSettings `denyAppRemoval` while strict
  mode is on (see honest limits below).
- A **DeviceActivityMonitor** extension re-asserts shields at session
  boundaries, and a **Shield** extension shows a custom block screen.

## Requirements

- macOS with **Xcode 15+**.
- An iPhone running **iOS 16+** (a real device — the Simulator cannot grant
  Screen Time authorization).
- The **Family Controls** capability. The development entitlement is enough for
  running on your own device, but signing it requires a **paid Apple Developer
  account ($99/yr)**. A free personal team cannot sign `family-controls` or
  App Groups, so the blocking features will not run under free provisioning —
  only the plain UI will.

## Project layout

```
project.yml      XcodeGen spec (generates FocusLock.xcodeproj)
App/             the SwiftUI app (UI, authorization, block controller)
Shared/          code compiled into the app AND both extensions
Monitor/         DeviceActivityMonitor extension
Shield/          ShieldConfiguration extension (custom block screen)
```

`Shared/` holds the App Group config, persistent state, PIN hashing and the
`BlockingManager`, so the app and the two extensions all read and write the
same `ManagedSettings` store and saved selection.

## Generate the Xcode project

The `.xcodeproj` is generated from `project.yml` and is **not** committed.

**Option A — XcodeGen (recommended):**

```bash
brew install xcodegen   # if you don't have it
cd blocker-app
xcodegen generate
open FocusLock.xcodeproj
```

**Option B — no XcodeGen:** create a new iOS App in Xcode named `FocusLock`,
then add two targets (*Device Activity Monitor Extension* and *Shield
Configuration Extension*), and drag in the `App/`, `Shared/`, `Monitor/` and
`Shield/` source files, adding `Shared/` to all three targets.

## Configure signing (once)

1. In **Signing & Capabilities** for each of the three targets, pick your Team.
2. Change the bundle IDs from `com.example.focuslock*` to your own prefix.
3. Add the **Family Controls** capability to all three targets.
4. Add the **App Groups** capability to all three and create one group, then set
   it in `Shared/AppGroup.swift`, `App/FocusLock.entitlements`,
   `Monitor/Monitor.entitlements` and `Shield/Shield.entitlements` (they must
   all match).
5. Build to your iPhone, launch, tap **Grant access** to authorize Screen Time.

## Strict mode — honest limits

- `denyAppRemoval` hides the Delete option while active, but with `.individual`
  authorization (what a personal app uses) you can revoke Screen Time access in
  **Settings → Screen Time** and then delete the app. For a hard lock, set a
  Screen Time passcode you don't hold, or supervise the device with Apple
  Configurator and a `allowAppRemoval = false` profile.
- A **factory reset always removes everything.** No iOS app can survive a wipe.
  "Undeletable by me" is high-friction, never absolute.
