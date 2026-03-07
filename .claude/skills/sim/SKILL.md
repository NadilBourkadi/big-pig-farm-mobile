---
name: sim
description: Build BigPigFarm for the iOS Simulator and launch it
argument-hint: "[optional: simulator name, e.g. 'iPhone 16 Pro'. Defaults to iPhone 17]"
---

# Sim — Build and Launch in Simulator

Builds the current worktree's BigPigFarm scheme and launches it on an iOS Simulator.
No Xcode required — fully CLI-driven.

## Flow

### Step 1 — Pick target device

Use the argument if provided (e.g. `/sim iPhone 16 Pro`), otherwise default to `iPhone 17`.

### Step 2 — Boot simulator and open Simulator.app

Run these as two separate Bash calls (never chain with &&):

```
xcrun simctl boot "<device-name>"
```

This is idempotent — silently succeeds even if the device is already booted.

Then bring the Simulator window to the foreground:

```
open -a Simulator
```

### Step 3 — Build

```
xcodebuild -scheme BigPigFarm -destination 'platform=iOS Simulator,name=<device-name>' build 2>&1 | tail -5
```

If the build fails, print the last 40 lines of output and stop. Do not proceed to install.

### Step 4 — Find the .app

Use the Glob tool to locate the built app in DerivedData:

Pattern: `~/Library/Developer/Xcode/DerivedData/BigPigFarm-*/Build/Products/Debug-iphonesimulator/BigPigFarm.app`

Take the first result. If none found, report the error and stop.

### Step 5 — Install and launch

Two separate Bash calls:

```
xcrun simctl install booted <app-path>
xcrun simctl launch booted com.bigpigfarm.app
```

### Step 6 — Confirm

Print a one-line summary: device name, whether this was a fresh build or reused existing, and the bundle ID launched. Example:

```
Launched com.bigpigfarm.app on iPhone 17 (fresh build)
```

## Notes

- **Never chain commands** with `&&` or `;` — each Bash call must be separate (CLAUDE.md rule)
- The build uses the worktree's `.xcodeproj`, not the main repo's
- `xcrun simctl boot` errors with "Unable to boot device in current state: Booted" are safe to ignore — the device is already ready
- If the user wants to see a different screen/state, they can navigate manually after launch
