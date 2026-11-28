---
name: new-repo
description: "Use when the owner asks for a new project or a new repository: set it up whole for factorium without asking (repository, gate, fits, factorium.toml, the checkout), and report it."
---

# Setting up a new repo

The owner says "start a new project" or "make a new repo": set it up whole, without a question in between. This is the setup before factorium takes over, so it is committed and pushed to the default branch directly, the one time a tech lead writes to a project.

## Steps

1. **Repository.** One the owner names is used as it is. Otherwise `gh repo create <owner>/<name> --private --clone` into `~/Developments/<name>`, named as the owner said, public only when they said so.
2. **Gate.** `gate.sh` runs the checks the stack can run today (the coding role of that stack says which). `factorium.toml` has `[gate]` with `fast = "./gate.sh"` and its limit, and `regenerated` listing the fits' baselines.

   `slow` holds only what the fast gate lacks: release builds, `truefit model` and its traces, simulator runs. A repo with nothing more leaves `slow` out; never `slow = "./gate.sh"`, and never a slow script that calls `./gate.sh`, since a promotion whose tip a landing gated green runs only the slow steps. With slow steps, `slow` names their script and its limit.

   **A Homebrew project's release.** The repo is public (the tap's workflow checks it out). It holds no signing secret and no release workflow: the Developer ID identity and the notary key live only in sunfmin/homebrew-tap, and only its `release` workflow signs, notarizes and publishes. The repo's packaging/release.sh (a path in the new repo, not here) has two commands:
   - `build <vX.Y.Z> <outdir>`, which the tap's workflow runs on its macOS runner at the tag: builds `aarch64-apple-darwin` and `x86_64-apple-darwin` in release mode, checks each binary prints the tag's version, `lipo -create`s one universal binary into `<outdir>`, and writes `<outdir>/<repo>.rb`, the formula with `@URL@` and `@SHA256@` where the tap fills in the release asset. Other platforms the project's own ADR names are built and published beside it, by the repo, unsigned.
   - `cut <version>`, `[cut]`'s one step (`steps = ["packaging/release.sh cut $FACTORIUM_VERSION"]`, `formula = "sunfmin/tap/<repo>"`): writes the version where the build reads it, commits, tags `v<version>`, pushes the tag, runs `gh workflow run release.yml -R sunfmin/homebrew-tap -f repo=<repo> -f tag=v<version>`, finds that run and waits for it within `[cut] limit`; a failed or unfinished run fails the cut and deletes the tag it pushed, local and remote.

   The cut then checks what it published: the installed binary is universal (`lipo -archs` shows both) and Developer ID signed (`codesign -dv` shows `Authority=Developer ID Application` and a TeamIdentifier), or the cut fails. Without that signature macOS's firewall refuses any port the tool listens on, and Gatekeeper rejects a downloaded copy.
3. **Fits**: the skill wire-fits.
4. **Done when `./gate.sh` is green.** Commit and push to the default branch as one commit of the setup.
5. **Put it on the line**: `orca repo add --path <checkout>`, then `factorium checkout add <name> <checkout> --base <default branch> --role <dir>` with the role directory for its kind of work (the skill roles). Every work dir of the repo is then an Orca worktree, named, commented and removed when done: factorium makes its own, and a worker makes a scratch tree with `orca worktree create --name <name> --comment <why>` and removes it with `orca worktree rm`, never `git worktree add` or `git clone`.
6. **Report** the repo's link, the files written, and its entry in `factorium checkout list`. For a Homebrew project, report that `packaging/release.sh build` runs green locally into a temp dir and its `<repo>.rb` holds both placeholders. idle may file issues on it at once (slimfit's first sample): read them and block any that the first issues will make moot.
