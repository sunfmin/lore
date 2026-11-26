---
name: wire-fits
description: "Use when setting up a repo factorium runs, or when a repo's gate or [idle] lacks slimfit, truefit or docfit: put each fit in the stage it belongs to, adopted with its own init, so the repo needs no sibling read for how."
---

# Wiring the fits into a repo

Every repo factorium runs has all three fits, each in the stages below. A fit's `--help` is the manual for its part. This skill holds only how the fits sit together in a repo.

## The stages

A check goes in the cheapest stage that still catches what it guards before it can do harm.

| Stage | Where it runs | What goes there | slimfit | truefit | docfit |
|---|---|---|---|---|---|
| **Before `done`** | the worker, on its branch | the fast gate's cheap whole-repo steps, plus the tests of what the change touched | the touched crates' tests | `truefit contract` | `docfit check` |
| **Fast gate** | `gate.sh`, every landing, on its merge with proving | what no landing may break, in seconds to a minute or two | `slimfit check`, in place of the test command | `truefit contract`, where the repo declares stand-ins | `docfit check` |
| **Promotion** | the slow gate's script (`[gate] slow`), before the base moves | what takes minutes and guards only the base: release builds | the mutants of everything since the base (`mutants_target`) | `truefit model` and its traces | |
| **Idle** | the `[idle]` tasks line | what finds debt, not regressions: it files issues and blocks nothing | `slimfit next --all --sample 5` | `truefit next --all` | `docfit next --all` |

## Steps

1. **slimfit.** Run `slimfit doctor` and do each finding's fix, then `slimfit help costs` and `slimfit help factorium`, then `slimfit init`. It writes `slimfit.toml` and `.slimfit/baseline.json`. In `gate.sh`, `slimfit check` runs in place of the repo's own test command (`cargo test`, `swift test`, `pytest`…), never beside it. In `factorium.toml`, `[gate] regenerated` lists `.slimfit/baseline.json`. `.gitignore` has `.slimfit/out`. A language slimfit has no preset for is named in your hand-in; leave slimfit out of the gate there.

   The mutants run at promotion: `slimfit.toml` sets `mutants_target = "origin/main"` under `[check]` (the base branch's name in place of `main`). No landing owes a record of its mutants; at promotion, a worker that wrote none of the range picks, runs and records the mutants of everything since the base (`slimfit help factorium`). Set no pick count: the picker sizes its picks to the diff.
2. **truefit.** Write `truefit.toml` with `[promises] sources = ["CLAUDE.md", "docs/adr/*.md"]`: a promise is a decision, so it lives in an ADR. Run `truefit promise` and mark each candidate (`truefit promise --mark <hash> promise|not`). Register each promise as its `[[promise]]` with the test that checks it. A repo that drives other programs declares its stand-ins under `[contract]` (`truefit --help`, "truefit contract"). `truefit contract` runs in `gate.sh`; `truefit model` runs in the slow gate's script (`[gate] slow`), never in the fast gate.
3. **docfit.** Read `docfit --help`, `docfit init --help` and `docfit help local-refs`. Run `docfit init`.

   A repo's documents are docfit's kinds only (README, CLAUDE.md, ADRs, GLOSSARY…), never a SPEC.md: what a spec would say goes to ADRs, with its promises registered in truefit.

   `docfit init` registers the Markdown files and writes `.docfit/baseline.json`. Review each file it lists: register a file it holds to rehome under the kind that fits it, and take out of `ignore` a glob it added over documents. Add to `ignore` the globs of test data that writes local refs, and list in `not_issue_refs` each name that is no tracker here. In `gate.sh`, `docfit check` runs. In `factorium.toml`, `[gate] regenerated` lists `.docfit/baseline.json`.
4. **The idle line.** `factorium.toml`:

   ```toml
   [idle]
   tasks = "slimfit --version && truefit --version && docfit --version && slimfit next --all --sample 5 && truefit next --all && docfit next --all"
   every = 86400
   ```

   with a `limit` that covers the sample's mutant runs. idle files what it finds as issues of the repo, so the debt each fit's baseline holds becomes work.
5. **Done**: `./gate.sh` is green, `slimfit doctor` has no finding, `truefit next --all` and `docfit next --all` answer, and `slimfit.toml`, `.slimfit/baseline.json`, `truefit.toml`, `.truefit/`, `docfit.toml` and `.docfit/baseline.json` are committed with the gate change.
