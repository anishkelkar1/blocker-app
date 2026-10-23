# FocusLock

A personal focus app for iPhone that blocks distracting apps and websites,
with a strict "commitment" mode. Built on Apple's **Screen Time API**
(`FamilyControls` + `ManagedSettings` + `DeviceActivity`) — no MITM proxy, no
root helper, no VPN.

> Personal project. Not for the App Store.

## Features

- **Named blocklists** — reusable sets of apps/categories (system
  `FamilyActivityPicker`) plus website domains. Create as many as you like.
- **Recurring schedules** — run a blocklist on chosen weekdays between a start
  and end time. Driven by `DeviceActivity`, so blocks fire even when the app is
  closed.
- **Cross-browser website blocking** via a DNS-filtering packet tunnel, so a
  blocked domain fails to resolve in Safari, Chrome, Firefox and every app —
  no root CA, no TLS interception.
- **Manual focus sessions** — start one or more blocklists now, timed or until
  you stop. They stack with whatever schedules are running.
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
App/             the SwiftUI app (UI, authorization, block + tunnel control)
Shared/          code compiled into the app AND all extensions
Monitor/         DeviceActivityMonitor extension
Shield/          ShieldConfiguration extension (custom block screen)
Tunnel/          NEPacketTunnelProvider extension (DNS website filter)
```

`Shared/` holds the App Group config, persistent state, PIN hashing, the
`BlockingManager`, the domain matcher, and the `Blocklist` / `BlockSchedule`
models + stores — so the app and every extension read and write the same
`ManagedSettings` store, blocklists and schedules.

### Blocklists and schedules

- A **blocklist** (`Shared/Blocklist.swift`) bundles an encoded
  `FamilyActivitySelection` (apps/categories/Safari sites) with a list of
  website domains for the tunnel. Manage them in the **Blocklists** tab.
- A **schedule** (`Shared/BlockSchedule.swift`) points at a blocklist and runs
  it on chosen weekdays between a start/end time. `App/ScheduleManager.swift`
  registers one `DeviceActivity` monitor per weekday (`sch.<id>.<weekday>`); the
  monitor extension activates/deactivates the blocklist at the window edges and
  publishes its domains to `SharedState.activeDomains` for the tunnel.
- **Several blocklists can run at once** — started by hand and/or by
  overlapping schedules. The enforced block is the union of every active
  blocklist's apps, categories and domains (see `BlockingManager.recompute`).
- **Overnight windows** (end earlier than start) are supported: ScheduleManager
  splits them across midnight into an `.a` segment (start→23:59) and a `.b`
  segment (00:00→end next day). The block lifts for under a minute at midnight.

## Two blocking layers

FocusLock uses the two approaches together, because neither covers everything:

- **Screen Time (Family Controls)** blocks apps from launching, shields Safari
  sites, and enforces the can't-delete lock. The network can't do these.
- **DNS packet tunnel (`Tunnel/`)** blocks websites by domain in *every*
  browser and app. Screen Time's site blocking is effectively Safari-only.

### How the tunnel works

It runs as a user-approved VPN in standard routing mode (no MDM, no supervised
device). It advertises itself as the system DNS server, then answers blocked
hosts with NXDOMAIN and forwards the rest to an upstream resolver. It reads
only the queried hostname.

**Honest limits of the tunnel:**

- **Host/domain level only.** It never decrypts TLS, so it cannot match a
  keyword inside a URL path or query — only the site's host. True URL-keyword
  blocking would require a root CA + TLS interception (what Freedom does), which
  breaks cert-pinned apps and exposes all your traffic. Out of scope by design.
- **Bypassable** by apps that use hardcoded IPs or their own DoH/DoT resolver.
- IPv6 and TCP/53 are TODO; `Tunnel/PacketTunnelProvider.swift` is IPv4 UDP DNS.
- The packet/DNS code is hand-rolled and needs on-device testing before you
  rely on it.

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

1. In **Signing & Capabilities** for each of the four targets, pick your Team.
2. Change the bundle IDs from `com.example.focuslock*` to your own prefix. Keep
   the tunnel's id in sync with `providerBundleID` in `App/TunnelController.swift`.
3. Add the **Family Controls** capability to the app, Monitor and Shield targets.
4. Add the **Network Extension** capability (Packet Tunnel) to the **app** and
   the **Tunnel** target.
5. Add the **App Groups** capability to all four targets and create one group,
   then set it in `Shared/AppGroup.swift`, `App/FocusLock.entitlements`,
   `Monitor/Monitor.entitlements`, `Shield/Shield.entitlements` and
   `Tunnel/Tunnel.entitlements` (they must all match).
6. Build to your iPhone, launch, tap **Grant access** to authorize Screen Time.
   The first time a session starts the website filter, iOS prompts to **add a
   VPN configuration** — approve it.

## Strict mode — honest limits

- `denyAppRemoval` hides the Delete option while active, but with `.individual`
  authorization (what a personal app uses) you can revoke Screen Time access in
  **Settings → Screen Time** and then delete the app. For a hard lock, set a
  Screen Time passcode you don't hold, or supervise the device with Apple
  Configurator and a `allowAppRemoval = false` profile.
- A **factory reset always removes everything.** No iOS app can survive a wipe.
  "Undeletable by me" is high-friction, never absolute.
