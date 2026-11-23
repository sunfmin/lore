---
name: hand-in
description: "Use before handing in a change to a Rust CLI: the gate run whole, the README, the checklist of the agent-cli rules, and a change that comes back."
---

# Handing the work in

The general hand-in is the core of the role coder; this adds what a Rust CLI needs.

## Green gate

The repo's `gate.sh` is the definition of "may land", and what it runs is its own to say. Run it whole, as `sh gate.sh` (it may be checked out without the exec bit); a part run by hand is not the gate. A script you add is committed executable (`100755`). A new repo's gate runs the tests with `cargo nextest run`, refusing with the `brew` line when nextest is missing, and the doctests with `cargo test --doc`, which nextest does not run. An existing gate is changed only when the issue asks. Where the gate runs less, also run `cargo fmt --check`, `cargo clippy -- -D warnings` and `cargo test --workspace`.

## README current

The README says what the tool is, how to install it, and sends the reader to `--help`; it never repeats help. When a command, an install line or a requirement changes, the README changes in the same change.

## Before you hand in

Every rule of the skill agent-cli holds where the repo keeps it, and:

- [ ] An agent that never saw the tool runs its first command from `--help` and that command's `--help` alone
- [ ] Every refusal has a test asserting its fix
- [ ] Killing it mid-run and running it again loses nothing
- [ ] The gate, run whole, is green; the README current
- [ ] Each acceptance criterion kept as written, its command and what it printed the evidence. One that cannot pass as written, or a constraint you would depart from, is escalated first, never settled by a decision record alone
- [ ] Nothing built committed: a new repo's `.gitignore` holds `/target` before its first commit
- [ ] A new dependency is named in the hand-in with its version, licence and why no crate already in `Cargo.lock` does it

## When it comes back

- A change that comes back starts from the branch as origin holds it, which may be ahead of your worktree: `git fetch`, bring it up to the newest base, rerun the gate whole even where the reason given was not your code, and redo each criterion's evidence at the new head.
- Bring a pushed branch up to the base by merging the base into it: rewriting it would need a force push.
- `Cargo.lock` is the workspace's: a version bump or a dependency change rewrites it, so commit it with the change even where the issue scopes one crate. A conflict only in it: take the base's lock whole and let `cargo metadata --offline` add only your crates' entries; `cargo generate-lockfile` re-resolves every package and bloats the diff.

## The hand-in

It names any departure from the agent-cli rules and the decision that records it; each criterion's evidence is a command and what it printed.
