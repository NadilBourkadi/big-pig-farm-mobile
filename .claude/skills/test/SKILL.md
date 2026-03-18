---
name: test
description: Run the test suite. ALWAYS use this instead of running swift test or xcodebuild test directly — it runs in a subagent to keep context clean. Triggers on "run tests", "test this", "check tests", "verify it passes", or ANY test execution during /implement workflows. --fast for logic (default), --full for scene tests, --all for both.
argument-hint: "[--fast|--full|--all]"
---

# Test — Run Tests in Isolated Context

Runs the project's test suite in a subagent so verbose build output doesn't pollute the
main agent's context window. Returns a concise pass/fail summary.

## Modes

- `--fast` (default): Logic tests only via `swift test`. No simulator. ~4 seconds.
- `--full`: Scene/app tests via simulator (`xcodebuild test`). 30-60s.
- `--all`: Both logic and scene tests sequentially.

## Flow

### Step 1 — Parse mode

Read `$ARGUMENTS`. Default to `--fast` if empty or not provided.

### Step 2 — Launch test subagent

Launch `Agent(subagent_type="general-purpose", model="haiku")` with this prompt:

> You are a test runner. Run the test suite and return ONLY a structured result.
> Do not read source files, do not investigate failures, do not suggest fixes.
>
> Working directory: {{WORKTREE_PATH}}

Before launching the subagent, replace `{{WORKTREE_PATH}}` with the absolute path
of the current working directory (e.g. the worktree root).
>
> Run this command via the Bash tool using the RELATIVE path (never absolute):
>   `bash scripts/run-tests.sh <MODE>`
> IMPORTANT: Use exactly `bash scripts/run-tests.sh`, NOT an absolute path. The working directory is already correct.
> Use timeout 120000 for --fast, 300000 for --full or --all.
>
> Parse the output and return EXACTLY this format:
>
> ```
> MODE: fast|full|all
> RESULT: PASS|FAIL
> TOTAL: <number of tests>
> PASSED: <number>
> FAILED: <number>
> DURATION: <seconds>
>
> FAILURES (if any):
> - <TestFile.swift>:<line> — <test name> — <failure reason>
> ```
>
> If the build fails before tests run, return:
> ```
> MODE: <mode>
> RESULT: BUILD_FAILURE
> ERROR: <last 20 lines of build output>
> ```
>
> Count tests from the Swift Testing output line "Test run with N tests".
> For --all mode, sum the counts from both runs.

### Step 3 — Report

Print the subagent's structured result to the user verbatim. If there are failures,
suggest which files to investigate based on the test file names.

## Notes

- The subagent model is `haiku` — fast and cheap, since it's just running a command and parsing output.
- `--fast` runs `swift test` which compiles BigPigFarmCore (the platform-agnostic package) and
  runs BigPigFarmCoreTests. No simulator, no Xcode project needed.
- `--full` runs `xcodebuild test` against a per-worktree simulator for scene/app tests
  (SpriteKit, UIKit, SwiftUI dependent tests in BigPigFarmTests/).
- The script handles simulator lifecycle (create/boot/delete) automatically.
- **Never run xcodebuild with run_in_background** — simulators require exclusive access.
