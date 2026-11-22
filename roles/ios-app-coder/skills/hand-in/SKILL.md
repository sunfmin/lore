---
name: hand-in
description: "Use before handing in a change to an iOS app: the green gate, the README, and the checklist of evidence for each acceptance criterion."
---

# Handing the work in

## Green gate

The repo's `gate.sh` defines "may land". Run it whole, as it is, before you hand in: running parts of it by hand is not the gate. Its scripts are committed executable (`100755`). When the gate runs `slimfit check`, the records it asks for (growth, mutants, or `--no-mutants "<why>"` where the preset has no mutants tool) are part of the change. When it fails for something outside your scope (a missing Xcode or runtime, a test another change broke), escalate with what you ran and what it printed. Do not work around it.

## README current

The README says what the app is, what it keeps on the device, the Xcode it needs, and how to run the tests, the gate and the app in the simulator. When any of these changes, the README changes in the same change.

## Before you hand in

- [ ] The package imports no SwiftUI or UIKit, builds for macOS, and every behaviour the issue adds has a test on it that you saw fail before it passed.
- [ ] A changed stored type has a migration, and a test that opens the version before.
- [ ] A search of the sources for `URLSession`, `Network`, `CloudKit`, `StoreKit` and analytics SDKs finds nothing the spec or issue did not ask for.
- [ ] `scan.sh` of the skill current-swiftui is clean over the files you changed, or each hit kept says why.
- [ ] No name, icon, text, art or data of another app or of a real person is in the repo. No weights, compiled models or datasets are in git.
- [ ] The build has no warnings, and neither do the formatter and linter the repo configures (`swift format lint` with its `.swift-format`, SwiftLint with its `.swiftlint.yml`). The gate, run whole, is green, and the README is current.
- [ ] Nothing changed outside the paths the issue scopes. Old code you saw that should be modernized is named in the hand-in, not changed.
- [ ] Each acceptance criterion's evidence is a command and what it printed. A measured number states its machine and command. A screen the issue asks to see is a simulator screenshot (`xcrun simctl io <device id> screenshot`).

## Never shipped by you

You do not archive, export, sign for a device, upload, tag or release. A change ready to ship says so and stops.
