---
name: sign-for-development
description: "Use before any xcodebuild that must be development-signed (an iOS app run on the Mac, a build for a phone): importing the host's identity into a run's own keychain, the xcodebuild signing flags with an App Store Connect key, the errors to expect, and cleaning up."
---

# Signing for development

## The run's keychain

Run under `rolesmith env apple-dev-signing -- <command>`: it hands the run `APPLE_DEV_P12_B64`, `APPLE_DEV_P12_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY_B64` and `APPLE_DEV_TEAM`.

1. Write the p12 and the `.p8` from the credentials (`APPLE_DEV_P12_B64`, `ASC_PRIVATE_KEY_B64`, base64) into a directory only you can read (`umask 077`).
2. `security create-keychain -p <random> <kc>`, then `set-keychain-settings <kc>` and `unlock-keychain -p <random> <kc>`.
3. `security import <p12> -k <kc> -P <password> -T /usr/bin/codesign`.
4. `security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k <random> <kc>`.
5. Add `<kc>` to the user search list (`security list-keychains -d user -s <existing…> <kc>`), keeping the list as it was.
6. On exit, in a `trap`: restore the search list, `security delete-keychain <kc>`, and remove the key files.

Over SSH, the login keychain answers `User interaction is not allowed`. That is why the run makes its own.

## xcodebuild

Add `DEVELOPMENT_TEAM=<team> CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates -authenticationKeyPath <p8> -authenticationKeyID <id> -authenticationKeyIssuerID <issuer>`. Add `-allowProvisioningDeviceRegistration` when the destination is a Mac or a phone that may not be registered yet.

What to expect:
- `Ad Hoc code signing is not allowed with SDK 'iOS …'`: an iOS build for a Mac or a phone needs this development signing; ad hoc is refused.
- The first run on a new Mac or phone can fail with `Build input file cannot be found: …mobileprovision` while the new profile lands. The second run passes.
- `Your account already has an Apple Development signing certificate for this machine, but its private key is not installed`: the identity from the credentials is not in the run's keychain. Fix the import. Xcode's offer to revoke is never the fix.
