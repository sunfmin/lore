---
name: new-repo
description: "Use when the owner asks for a new project or a new repository: set it up whole for factorium without asking (repository, agent docs, gate, fits, factorium.toml, the checkout), and report it."
---

# Setting up a new repo

The owner says "start a new project" or "make a new repo": set it up whole, without a question in between. This is the setup before factorium takes over, so it is committed and pushed to the default branch directly, the one time a tech lead writes to a project.

## Steps

1. **Repository.** One the owner names is used as it is. Otherwise `gh repo create <owner>/<name> --private --clone` into `~/Developments/<name>`, named as the owner said, public only when they said so.
2. **Agent docs**, as the engineering skills expect them, with the recommended answer for every choice:
   - `docs/agents/issue-tracker.md`: issues live in factorium's tracker, read and written with `factorium issue add|list|show|comment|block <checkout> …`, `<checkout>` being this repo's name in `factorium checkout list`. Not GitHub's.
   - `docs/agents/domain.md`: single-context (a root `GLOSSARY.md` and `docs/adr/`, made when first needed).
   - `CLAUDE.md`, made when neither it nor `AGENTS.md` exists: what the repo is in a line, where its manual is, and the two pointers above. Nothing a command or a file already says.
   - No triage labels: factorium has none.
3. **Gate.** `gate.sh` runs the checks the stack can run today (the coding role of that stack says which). `factorium.toml` has `[gate]` with `fast` and `slow` and their limits, in the shape of the newest checkout's. A Homebrew project gets `[cut]` once its release script exists, or an issue that adds both.
4. **Fits**: the skill wire-fits.
5. **Done when `./gate.sh` is green.** Commit and push to the default branch as one commit of the setup.
6. **Put it on the line**: `orca repo add --path <checkout>`, then `factorium checkout add <name> <checkout> --base <default branch> --role <dir>` with the role directory for its kind of work (the skill roles).
7. **Report** the repo's link, the files written, and its entry in `factorium checkout list`. idle may file issues on it at once (slimfit's first sample): read them and block any that the first issues will make moot.
