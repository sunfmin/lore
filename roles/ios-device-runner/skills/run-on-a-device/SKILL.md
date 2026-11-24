---
name: run-on-a-device
description: "Use to run an iOS app's tests, or the app itself, on a real iPhone: finding the phone (this host first, then the hosts SSH reaches), building and signing on the host the phone is paired to, downloading model weights there from Hugging Face, running there, and getting the results and pictures back."
---

# Running on a real iPhone

`device-run.sh`, in this skill's directory, does every step below in one command. Use it, and read the steps when it fails or when the run needs something it does not do:

```sh
rolesmith env apple-dev-signing -- <skill dir>/device-run.sh --project <dir with project.yml> --scheme <scheme> \
   --copy-in there:.cache/<app>/models="Library/Application Support/<App>/models" --launch 120
```

It runs the same on the host the phone is plugged into (a person there, or you over SSH) as on any other: it finds the phone here first, and then builds and runs here.

- `--build` (build only; nothing reaches the phone), `--install`, `--launch [seconds]` (console attached) or `--test [targets…]` (results and pictures back in `--out`, default `.build/device-run`).
- `--configuration Release` when the numbers matter: speed and memory measured on a Debug build mislead (rollmind#65: an unoptimized resize took 8 s of a 10 s caption). Debug is the default.
- `--copy-in <src>=<dest>` puts files the app reads (models, a sample library) into its data container without bundling them. Run it again after every build: an upgrade keeps the container. `there:<path>` is a path on the phone's host, relative to its home; use it for models (below). A plain source is on your host and, with the phone elsewhere, must be under 100 MB.
- It finds the phone as below, signs in a keychain it removes on exit, and ends with one JSON line: the phone, its host, the action, the source commit it built (with `+uncommitted` when the checkout had changes) and its status. Exit 3 means no phone was found.

Everything for the phone happens on the host it is paired to: the build, the signing, the weights and the copy onto the phone. Only the source travels from your host. When the phone is on another host, the script mirrors the git checkout holding `--project` to `~/.cache/device-run/src/<repo>` there (the files git tracks, plus untracked ones it does not ignore; a second send takes about a second) and builds in that mirror. `--build-there` instead builds a checkout already on that host, at the path `--project` gives, as it is.

## Weights: from Hugging Face, on the phone's host

Model weights are never sent from your host. Download them on the phone's host, straight from the Hugging Face repo the project names, into the cache the project uses there, then copy them in with `--copy-in there:<path>`:

```sh
ssh <host> 'zsh -lc "hf download <org>/<repo> --local-dir ~/.cache/<app>/models"'
```

`hf download` fetches only files that are missing or changed, so run it before every run. A model the project has not published to Hugging Face yet cannot go on the phone. Say so on the issue rather than copying it across.

## Find the phone

1. **Here.** `xcrun devicectl list devices` on your own host: a row with Reality `physical` and State `available (paired)` is a phone you can use. If there is one, use it and look no further: build and run in one step (below).
2. **Over SSH**, only when none is paired here. Ask each host SSH reaches without a password (the `Host` entries of `~/.ssh/config`, or the hosts the issue names): `ssh -o BatchMode=yes -o ConnectTimeout=5 <host> xcrun devicectl list devices`. Take the first host with a physical, available, paired phone. A host that does not answer is skipped, not waited for.
3. **None anywhere:** escalate, with the hosts you asked and what each answered.

If the issue names a phone or a host, use that one. A phone that is shown but `unavailable` (locked, asleep, not trusted) needs a person, so escalate it the same way.

## Sign

The build is development-signed: the skill sign-for-development of the role apple-dev-signing gives the keychain and the flags. It happens on the phone's host; the credentials reach it on the build's stdin, never in a command line. A phone not yet registered needs one build naming it (`-destination id=<udid> -allowProvisioningDeviceRegistration`).

## Phone paired here: one step

`xcodebuild test -destination id=<udid> -only-testing:<targets> -derivedDataPath <dir> -resultBundlePath <bundle>`, plus the signing flags. Then read the bundle as in step 4 below.

## Phone on another host: send the source, build and run there

1. Send the source: mirror your checkout to the phone's host (the script's `send_source`: `git ls-files -co --exclude-standard`, then `rsync --delete --delete-excluded` of exactly those files).
2. On the phone's host, in the mirror: `xcodebuild build-for-testing -destination id=<udid> -only-testing:<targets> -derivedDataPath <dir>` plus the signing flags, with the signing keychain made there and removed after. It writes `Build/Products/`: the signed `.app`, the test bundles and a `<Scheme>_iphoneos<ver>-arm64.xctestrun`.
3. There: `xcodebuild test-without-building -xctestrun <file>.xctestrun -destination id=<udid> -resultBundlePath <bundle>`.
4. Read the result there: `xcrun xcresulttool get test-results summary --path <bundle> --compact`. Bring back the summary and `xcresulttool export attachments --path <bundle> --output-path <dir>`. In that directory, `manifest.json` maps each exported file to its test and its name.

Run this long command detached on the phone's host (`nohup …&`, writing a done file), and poll it with a bound. An SSH session that drops must not kill the run.

The phone must be paired to the host that runs steps 2 and 3. Xcode's "Connect via network" finds phones by Bonjour on the same local network. A host on another network does not see the phone, and SSH does not carry that discovery.

## Pictures from a phone

The test bundle runs in the app's sandbox on the phone. The harness writes and attaches its pictures as the skill render-screens of ios-app-coder says under "Off the simulator", and they leave through the result bundle (step 4).

## What to report

- The phone: name, model, iOS version, and the host it is paired to.
- Pass/fail counts, and each failure's message, quoted from the result bundle.
- Every failure the simulator did not show, said as a finding: for example, an order that follows the phone's language.
- One plain line for each picture you looked at.
