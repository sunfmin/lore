# Render tests on the Mac

The app-hosted render-test bundle also runs as an iOS app directly on an Apple Silicon Mac, with no simulator booted. On rollmind (15 render tests, Xcode 27.2), a warm build plus the run took 20 s, against 120–150 s on a fresh simulator. Use it for the narrow run while you work, and in the fast gate where the repo puts it there. The simulator run stays the authority: see "What only the simulator shows".

## Running

```sh
xcodebuild test -project <App.xcodeproj> -scheme <Scheme> \
  -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
  -only-testing:<RenderTarget> \
  -derivedDataPath … -resultBundlePath … \
  DEVELOPMENT_TEAM=<team> CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  -authenticationKeyPath <key.p8> -authenticationKeyID <id> -authenticationKeyIssuerID <issuer>
```

- This is the "Designed for iPad" destination, which the project already offers. Mac Catalyst is a different build: it needs project changes and draws a Mac window.
- An iOS app runs on the Mac only with development signing. An ad hoc build fails with `Ad Hoc code signing is not allowed with SDK 'iOS …'`. The App Store Connect API key lets Xcode register the Mac and make a team profile with no Xcode account login. The first run on a host can fail with `Build input file cannot be found: …mobileprovision` while the new profile lands; the second run passes.
- The identity is an Apple Development certificate and its private key. Import them into a keychain the run makes for itself:
  - `security create-keychain` and `unlock-keychain`;
  - `security import <p12> -T /usr/bin/codesign`;
  - `security set-key-partition-list -S apple-tool:,apple:,codesign:`;
  - add the keychain to the user search list.
  
  Over SSH the login keychain answers `User interaction is not allowed`, so do not import into it.
- The p12 and the API key are the host's. The repo's script or the host's secret store names where they are; on Felix's hosts they are the mytokens entries `apple-development-p12` and `asc-api-key`. If the host has neither, escalate.
- Use the certificate the host gives you. Xcode may offer to revoke the account's certificate "for this machine" and make a new one; revoking breaks every host that signs with it.

## Getting the pictures out

On the Mac the app runs in a sandbox. A write to `<repo>/…/out/` fails with a permission error. A file the app writes in its own container cannot be read from outside it: TCC answers `Operation not permitted`. So when `ProcessInfo.processInfo.isiOSAppOnMac` is true, the harness:

- writes the PNG under `URL.temporaryDirectory` (inside the sandbox), so the harness's own file checks still hold;
- records it as a Swift Testing attachment: `Attachment.record(pngData, named: "\(name).png")`. `pngData` is `Data`, and the file says `import Foundation`, which brings the overlay that makes `Data` attachable. Attaching the `UIImage` instead compiles, but on the Mac the bundle then fails to load (`Symbol not found … AttachableAsImage … _Testing_UIKit`).

After the run, `xcrun xcresulttool export attachments --path <result bundle> --output-path <dir>` writes the PNGs out. In that directory, `manifest.json` maps each exported file to its test and name. Look at those pictures as the render-screens skill says.

## What only the simulator shows

- **Dynamic Type.** `.dynamicTypeSize(.accessibility5)` draws at the default size, and the text-size checks still pass. On the Mac a text-size test proves nothing. Mark it `.disabled(if: ProcessInfo.processInfo.isiOSAppOnMac, "Dynamic Type sizes do not apply on the Mac")` so it reports itself skipped.
- **The phone's shape.** A window on the app's scene is 375×667 pt at scale 1, with no notch and no home indicator. Safe-area checks, the largest-phone width and pixel reads at device scale belong to the simulator run.
- **XCUITest.** UI tests fail with `UI tests are not supported on My Mac (Designed for iPad)`. `performAccessibilityAudit` journeys stay on the simulator.

So the repo's slow gate keeps the simulator run, and the Mac run never replaces it.
