---
name: render-on-the-mac
description: "Use to run an iOS app's render tests on the Mac with no simulator: the Designed-for-iPad destination, the harness change for the sandbox, getting the pictures out, and what only the simulator shows."
---

# Render tests on the Mac

## Running

```sh
xcodebuild test -project <App.xcodeproj> -scheme <Scheme> \
  -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
  -only-testing:<RenderTarget> \
  -derivedDataPath … -resultBundlePath … \
  <the signing flags of sign-for-development, with -allowProvisioningDeviceRegistration>
```

- This is the "Designed for iPad" destination, which the project already offers. Mac Catalyst is a different build: it needs project changes and draws a Mac window.
- The run is development-signed: the skill sign-for-development of the role apple-dev-signing gives the keychain and the signing flags.

## Getting the pictures out

On the Mac the app runs in a sandbox. The harness writes and attaches its pictures, and they leave through the result bundle, as the skill render-screens says under "Off the simulator". In the export, `manifest.json` maps each file to its test and name.

## What only the simulator shows

- **Dynamic Type.** `.dynamicTypeSize(.accessibility5)` draws at the default size, and the text-size checks still pass. On the Mac a text-size test proves nothing. Mark it `.disabled(if: ProcessInfo.processInfo.isiOSAppOnMac, "Dynamic Type sizes do not apply on the Mac")` so it reports itself skipped.
- **The phone's shape.** A window on the app's scene is 375×667 pt at scale 1, with no notch and no home indicator. Safe-area checks, the largest-phone width and pixel reads at device scale belong to the simulator run.
- **XCUITest.** UI tests fail with `UI tests are not supported on My Mac (Designed for iPad)`. `performAccessibilityAudit` journeys stay on the simulator.

So the repo's slow gate keeps the simulator run, and the Mac run never replaces it.
