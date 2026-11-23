---
name: render-screens
description: "Use when a change adds or changes a screen, or when a repo has no render tests for its screens yet: render the app's real SwiftUI screens in a test, hold them to what they say, their layout and the pixels words cannot describe, across a matrix of sizes, appearances and text sizes; look at the pictures; run them in the gate."
---

# Rendering screens in tests

A **render test** draws a real screen of the app, the way the app draws it, inside an app-hosted test bundle. It writes the picture as a PNG for a person or agent to look at, and asserts on:

- **what the screen says:** its accessibility tree, which is also what VoiceOver reads;
- **its layout:** the frames of those elements;
- **pixels:** only where words cannot say it, such as which end of a bar is white, or whether a board fills the width.

It does not compare against a stored reference image. Why: a reference image breaks on every simulator or Xcode update and differs by machine architecture, and the assertions above hold across both.

## The harness (one small file per repo)

- A `bundle.unit-test` target hosted by the app (in `project.yml`), using `@testable import` of the app, plus the package's test fakes for the edges (scripted engine, in-memory store, fixed clock).
- `render(name, size:, style:, of: { view })`:
  - puts the view in a `UIHostingController` in a new `UIWindow` on the app's scene (real safe areas), or in a window of a stated size;
  - waits until the screen has settled (see below);
  - draws with `drawHierarchy(in:afterScreenUpdates: true)` into `UIGraphicsImageRenderer`;
  - writes `<repo>/…/out/<name>.png` (git-ignored);
  - returns the PNG's URL, the words (the accessibility labels and values, walked through views and elements together), and each word's frame;
  - hides the window afterwards.
- SwiftUI builds no accessibility tree unless something is listening. One way to switch it on is a private symbol (`_AXSSetAutomationEnabled`, through `dlsym`). If you copy that, the harness fails the test when the switch is not found. It must never return an empty word list that silently passes `#expect(!says(…))` checks. Private symbols can vanish in any iOS release.
- Interact through accessibility (`accessibilityActivate()` on the element with that label), never by setting state behind the view's back.
- Suites are `@MainActor` and `.serialized`: one key window at a time.

## Settling

Wait for a condition, never a count of sleeps. For example: the model's state says the async answer has arrived, the expected word is present, or two successive renders give the same words. Bound the wait (2 s) and fail with what was last seen. Turn animations off in the test (`.transaction { $0.animation = nil }` on the subject, or `UIView.setAnimationsEnabled(false)`).

## The matrix

Each screen the change touches gets one render test per row it can differ in, written as `@Test(arguments:)`:

- appearance: light and dark (`overrideUserInterfaceStyle` on window and controller);
- text size: the default and one accessibility size (`.dynamicTypeSize(.accessibility3)` on the subject);
- width: the smallest iPhone the deployment target supports (375×667 pt) and the largest (440×956 pt); on iPad, the sizes and Split View widths the app supports;
- language: each one the app ships, plus the longest one when the app is localized;
- state: empty, loading, error, long content, as the screen has them.

Do not multiply every row by every other. Cover each row once, and add combinations only where a bug was found.

## What to assert

- **Words:** the screen says what the acceptance criteria say it shows, and does not say what it must hide.
- **Layout, from word frames:**
  - every labelled element is inside the window and its safe area;
  - no two labelled elements' frames overlap;
  - every control is at least 44×44 pt;
  - at the accessibility text size, nothing is pushed out of the window or overlapped.
- **Pixels,** read from the PNG at stated points: only for a fact that words and frames cannot carry.

## Looking at the pictures

After the run, open each PNG of the screens your change touched. In the hand-in, write one plain line per picture saying what it shows. That line is evidence, not a verdict. A picture that contradicts its assertions (blank, clipped, the wrong screen) is a failure to fix, even when the test passed. A model's opinion of a picture is never the gate.

## In the gate

- Render tests that no gate runs rot. The gate builds the app-hosted bundle and runs it: `xcodebuild test -only-testing:<RenderTarget>`, on a device by id, with its own `-derivedDataPath` and `-resultBundlePath` (see the skill build-and-test).
- The render tests also run as an iOS app directly on the Mac, signed for development, with no simulator, in seconds. Use that for the narrow run while you work and, where the repo puts it there, in the fast gate. The simulator run stays in the slow gate: the Mac does not show Dynamic Type sizes, the phone's shape or XCUITest. How, and how the pictures get out of the app's sandbox: [on-the-mac.md](on-the-mac.md).
- If the render tests make the fast gate too slow on a simulator, they go in the slow gate, and the fast gate keeps the package's tests (and the Mac run, where the repo has one).
- A few XCUITest journeys belong in the slow gate too, each calling `try app.performAccessibilityAudit()` on the screens it reaches. The audit finds clipped text, Dynamic Type breakage, contrast problems and small hit regions without any reference image.

## Reference-image snapshots (only when the repo opts in)

swift-snapshot-testing is a third-party package: use it only where the spec or the issue names it. When it is named:

- the gate runs with `SNAPSHOT_TESTING_RECORD=never`, so a run never records its way to green;
- keep `precision` at 1 and absorb rendering noise with `perceptualPrecision: 0.98`, never by lowering `precision`;
- the device and runtime are pinned and checked by the gate;
- references are re-recorded only in a change of their own, when Xcode moves.
