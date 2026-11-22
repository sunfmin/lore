---
name: build-and-test
description: "Use on every change to an iOS app, and first when something is reported broken: where tests go, the narrowest test to run, xcodebuild flags for an unattended worktree, the simulator, reading failures."
---

# Building and testing

## Where tests go

- Tests are Swift Testing (`@Test`, `#expect`, `#require`) on the package's public types. A test that reaches a private part, or breaks on a refactor that kept behaviour, tests past the interface: move it to the public seam.
- The only fakes are an in-memory store, a temporary directory, the clock and seed passed in, and a stand-in behind a protocol for an iOS-only edge (PhotoKit, `BGTaskScheduler`). The package itself runs as it is, never mocked. Swift Testing runs tests in parallel and in any order, so each test makes its own store and directory and shares no state with another.
- Test data is made by the test: rendered text, generated images, hand-made vectors. A small committed fixture (under 1 MB, openly licensed, its source named in the test) is the exception. A test that needs a model file reads it from the cache directory the repo names, and is skipped with a stated reason (`.enabled(if:)`) when the file is absent. Model tests use `.cpuOnly` compute units, so results do not depend on the machine.
- A stored type has a round-trip test, and a changed one has a test that opens a store written by the version before.
- A screen is tested by rendering it (the skill render-screens). A UI test (XCUITest) is for a flow neither a unit test nor a render test reaches:
  - It launches with launch arguments that open an in-memory store with known data, and sets the colour scheme inside the app (`.preferredColorScheme`).
  - It finds elements by accessibility identifier, never by position or translatable text. An identifier set on a container covers its `.overlay`.
  - It holds on every device size: find a tab among `app.buttons`, never through `app.tabBars`.

## Running them

- See a test fail before writing the code that makes it pass. It must fail on its own `#expect`, not on a build error. A bug starts from a test that fails the way it was reported.
- Run the cheapest test that covers the change:
  - package code: `swift test --filter <Suite>/<test>` on the host, with no simulator;
  - app code or a UI test: `xcodebuild test -only-testing:<target>/<suite>/<test>`.
  - Then run the whole gate before you hand in.
- In a worktree, give every xcodebuild run its own `-derivedDataPath`, `-clonedSourcePackagesDirPath` and `-resultBundlePath` inside the worktree, and a destination by `id=`. Worktrees that share DerivedData, the package cache or a simulator overwrite each other's builds and app sandboxes.
- Keep the log short and the failure exact. Pipe xcodebuild through `xcbeautify --quieter` when the repo has it, else `grep -E 'error:|warning:|failed|passed'`, and keep the full log in a file. Read a failure from the result bundle (`xcrun xcresulttool get test-results summary` / `test-details --test-id <id>`), never from the tail of the log.
- A failure that comes and goes: pin the clock, the seed and the order of async work, then run it repeatedly (`swift test --filter … ` in a loop, or `-test-iterations 50 -run-tests-until-failure`) until it fails often enough to chase.

## The simulator

- The gate names or picks its destination, and a run by hand uses the same device, by id. Pick devices from `xcrun simctl list devices available --json`, never a hard-coded name. When none fits, create one (`xcrun simctl create <name> <devicetype> <runtime>`), use it by id, and delete only devices you created.
- Simulator builds need no signing identity. When one is asked for, the project or the gate is wrong: the fix is `CODE_SIGNING_ALLOWED=NO` for simulator builds, never a certificate.
- A missing runtime, a device that will not boot, or a broken Xcode is the host's problem, not yours. Escalate it with what you ran and what it printed. Do not change the gate to get around it.
