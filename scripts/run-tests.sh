#!/bin/bash
# run-tests.sh — Per-worktree iOS test runner.
#
# Creates a private simulator named after the current worktree (or a supplied
# slug), runs the test suite against it, then deletes it. This avoids simulator
# name conflicts when multiple Claude sessions run tests in parallel.
#
# Usage:
#   bash scripts/run-tests.sh [slug]
#
# If no slug is given, the basename of the current working directory is used
# (e.g. "a0p-pig-label" when run from .claude/worktrees/a0p-pig-label/).
#
# Requirements:
#   - Xcode with iOS simulator runtime installed
#   - xcodegen already run (BigPigFarm.xcodeproj must exist)

set -euo pipefail

SLUG="${1:-$(basename "$(pwd)")}"
SIM_NAME="BPF-Test-${SLUG}"
RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-2"
SCHEME="BigPigFarmTests"

echo "==> Creating simulator: $SIM_NAME"
UDID=$(xcrun simctl create "$SIM_NAME" "iPhone 16e" "$RUNTIME")
echo "    UDID: $UDID"

cleanup() {
    echo "==> Deleting simulator $UDID"
    xcrun simctl delete "$UDID" || true
}
trap cleanup EXIT

echo "==> Booting simulator"
xcrun simctl boot "$UDID"

echo "==> Running $SCHEME"
xcodebuild -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  test 2>&1 | tail -200

echo "==> Tests complete"
