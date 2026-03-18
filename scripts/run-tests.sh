#!/bin/bash
# run-tests.sh — Test runner with fast (SPM) and full (simulator) modes.
#
# Usage:
#   bash scripts/run-tests.sh [--fast|--full|--all] [slug]
#
# --fast (default): Runs logic tests via `swift test` on macOS. No simulator.
#   ~1,076 tests in ~4 seconds.
# --full: Creates a per-worktree simulator and runs scene/app tests only
#   (BigPigFarmTests target — SpriteKit, UIKit, SwiftUI dependent tests).
# --all: Runs both --fast and --full sequentially.
#
# If no slug is given for --full/--all, the basename of the current working
# directory is used (e.g. "a0p-pig-label" from .claude/worktrees/a0p-pig-label/).
#
# Requirements:
#   - Swift toolchain (for --fast)
#   - Xcode with iOS simulator runtime (for --full/--all)
#   - xcodegen already run (BigPigFarm.xcodeproj must exist for --full/--all)

set -euo pipefail

MODE="fast"
SLUG=""

for arg in "$@"; do
    case "$arg" in
        --fast) MODE="fast" ;;
        --full) MODE="full" ;;
        --all)  MODE="all" ;;
        *)      SLUG="$arg" ;;
    esac
done

# --- Fast mode: swift test (logic tests, no simulator) ---

run_fast() {
    echo "==> Running logic tests via swift test (no simulator)"
    swift test 2>&1
    echo "==> Logic tests complete"
}

# --- Full mode: xcodebuild test (scene tests, simulator required) ---

run_full() {
    SLUG="${SLUG:-$(basename "$(pwd)")}"
    local SIM_NAME="BPF-Test-${SLUG}"
    local RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-2"
    local SCHEME="BigPigFarmTests"

    echo "==> Creating simulator: $SIM_NAME"
    local UDID
    UDID=$(xcrun simctl create "$SIM_NAME" "iPhone 16e" "$RUNTIME")
    echo "    UDID: $UDID"

    cleanup() {
        echo "==> Deleting simulator $UDID"
        xcrun simctl delete "$UDID" || true
    }
    trap cleanup EXIT

    echo "==> Booting simulator"
    xcrun simctl boot "$UDID"

    echo "==> Running $SCHEME (scene + app tests)"
    xcodebuild -scheme "$SCHEME" \
      -destination "platform=iOS Simulator,id=$UDID" \
      test 2>&1 | tail -200

    echo "==> Scene tests complete"
}

# --- Dispatch ---

case "$MODE" in
    fast) run_fast ;;
    full) run_full ;;
    all)
        run_fast
        echo ""
        echo "=========================================="
        echo ""
        run_full
        ;;
esac
