---
name: hand-in
description: "Use before handing in a change to a Rust CLI: the gate and the checks of what changed, the README, the checklist of the agent-cli rules, and a change that comes back."
---

# Handing the work in

The general hand-in is the core of the role coder; this adds what a Rust CLI needs.

## Green gate

The repo's `gate.sh` is the definition of "may land", and what it runs is its own to say. Who runs it whole is the core of the role coder's to say (step 3). Where you run it, run it whole, as `sh gate.sh` (it may be checked out without the exec bit).

Under factorium, the checks of what the change touched are `cargo fmt --check`, `cargo clippy -- -D warnings`, the tests of each crate touched (`cargo nextest run -p <crate>`, its doctests with `cargo test --doc -p <crate>`) and `docfit check`, the tests through `factorium worker exclusive`.

A script you add is committed executable (`100755`). A new repo's gate runs the tests with `cargo nextest run`, refusing with the `brew` line when nextest is missing, and the doctests with `cargo test --doc`, which nextest does not run. An existing gate is changed only when the issue asks. Where the gate runs less, also run `cargo fmt --check`, `cargo clippy -- -D warnings` and `cargo test --workspace`.

## The README

The gate's `docfit check` holds the README to its kind and budget. Beyond that: it says how to install the tool and sends the reader to `--help` for the rest; when an install line or a requirement changes, the README changes in the same change.

## Before you hand in

Every rule of the skill agent-cli holds where the repo keeps it, and:

- [ ] An agent that never saw the tool runs its first command from `--help` and that command's `--help` alone
- [ ] Every refusal has a test asserting its fix
- [ ] Killing it mid-run and running it again loses nothing
- [ ] The checks of the Green gate above are green, its `docfit check` among them
- [ ] Each acceptance criterion kept as written, its command and what it printed the evidence. One that cannot pass as written, or a constraint you would depart from, is escalated first, never settled by a decision record alone
- [ ] Nothing built committed: a new repo's `.gitignore` holds `/target` before its first commit
- [ ] A new dependency is named in the hand-in with its version, licence and why no crate already in `Cargo.lock` does it

## When it comes back

- A change that comes back starts from the branch as origin holds it, which may be ahead of your worktree: `git fetch`, bring it up to the newest base, rerun the checks of the Green gate above even where the reason given was not your code, and redo each criterion's evidence at the new head.
- Bring a pushed branch up to the base by merging the base into it: rewriting it would need a force push.
- `Cargo.lock` is the workspace's: a version bump or a dependency change rewrites it, so commit it with the change even where the issue scopes one crate. A conflict only in it: take the base's lock whole and let `cargo metadata --offline` add only your crates' entries; `cargo generate-lockfile` re-resolves every package and bloats the diff.

## The hand-in

It names any departure from the agent-cli rules and the decision that records it; each criterion's evidence is a command and what it printed.
