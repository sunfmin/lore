---
name: run-on-a-device
description: "Use to run an iOS app's tests, or the app itself, on a real iPhone: signing with the host's identity, building on your host, running on the host the phone is paired to (over SSH when that is another host), and getting the results and pictures back."
---

# Running on a real iPhone

Measured on rollmind (2026-11-23): building on macnoMac-Studio took 32 s, copying the 43 MB of products to FelixMBAirM1 took 42 s, and running 22 tests on its iPhone 17 Pro Max took 60 s. The same build on the slower host is several minutes, so build on the fast host and run where the phone is.

## Sign

- Use the identity the host's secret store holds. On Felix's hosts that is mytokens:
  - `apple-development-p12`: fields `P12 (base64)` and `P12 password`, an Apple Development certificate and its key;
  - `asc-api-key`: fields `Key ID`, `Issuer ID` and `Key (base64 .p8)`.
- Import the p12 into a keychain the run makes for itself:
  - `security create-keychain`, `set-keychain-settings` and `unlock-keychain`;
  - `security import … -T /usr/bin/codesign`;
  - `security set-key-partition-list -S apple-tool:,apple:,codesign:`;
  - add it to the user search list.
  
  Over SSH the login keychain answers `User interaction is not allowed`. Remove the keychain and every key file on exit (a `trap`).
- Build with `DEVELOPMENT_TEAM=<team> CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates` and the key (`-authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID`). Xcode then makes the team profile with no account login. A phone that is not yet registered needs a build naming it (`-destination id=<udid> -allowProvisioningDeviceRegistration`) once.
- Xcode may say the account has a certificate "for this machine" whose key is not here, and offer to revoke it. Use the identity from the secret store instead.

## Build here, run there

1. On your host: `xcodebuild build-for-testing -destination 'generic/platform=iOS' -only-testing:<targets> -derivedDataPath <dir>` plus the signing above. It writes `Build/Products/`: the signed `.app`, the test bundles and a `<Scheme>_iphoneos<ver>-arm64.xctestrun`.
2. Copy `Build/Products/` to the phone's host: `tar` over `ssh`/`scp`, or `rsync` when the last run's copy is still there.
3. On the phone's host: `xcodebuild test-without-building -xctestrun <file>.xctestrun -destination id=<udid> -resultBundlePath <bundle>`. No signing is needed there.
4. Read the result there: `xcrun xcresulttool get test-results summary --path <bundle> --compact`. Bring back the summary and `xcresulttool export attachments --path <bundle> --output-path <dir>`. In that directory, `manifest.json` maps each exported file to its test and its name.

Run this long command detached on the phone's host (`nohup …&`, writing a done file), and poll it with a bound. An SSH session that drops must not kill the run.

The phone must be paired to the host that runs step 3. Xcode's "Connect via network" finds phones by Bonjour on the same local network. A host on another network does not see the phone, and SSH does not carry that discovery.

## Pictures from a phone

A test on the phone cannot write into the repo: the bundle runs in the app's sandbox on the phone. The test writes in the app's temporary directory, and records each PNG as a Swift Testing attachment: `Attachment.record(pngData, named: "<name>.png")`, with `pngData` as `Data` and `import Foundation` in the file. The pictures leave through the result bundle (step 4).

## What to report

- The phone: name, model, iOS version, and the host it is paired to.
- Pass/fail counts, and each failure's message, quoted from the result bundle.
- Every failure the simulator did not show, said as a finding: for example, an order that follows the phone's language.
- One plain line for each picture you looked at.
