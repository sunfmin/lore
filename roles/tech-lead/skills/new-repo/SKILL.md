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

   A Homebrew project gets `[cut]` once its release script exists, or an issue that adds both.
3. **Fits**: the skill wire-fits.
4. **Done when `./gate.sh` is green.** Commit and push to the default branch as one commit of the setup.
5. **Put it on the line**: `orca repo add --path <checkout>`, then `factorium checkout add <name> <checkout> --base <default branch> --role <dir>` with the role directory for its kind of work (the skill roles). Every work dir of the repo is then an Orca worktree, named, commented and removed when done: factorium makes its own, and a worker makes a scratch tree with `orca worktree create --name <name> --comment <why>` and removes it with `orca worktree rm`, never `git worktree add` or `git clone`.
6. **Report** the repo's link, the files written, and its entry in `factorium checkout list`. idle may file issues on it at once (slimfit's first sample): read them and block any that the first issues will make moot.
