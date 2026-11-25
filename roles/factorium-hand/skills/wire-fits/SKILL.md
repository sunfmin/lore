---
name: wire-fits
description: "Use when setting up a repo factorium runs, or when a repo's gate or [idle] lacks slimfit or truefit: put each fit in the gate and on the idle line, adopted with its own init, so the repo needs no sibling read for how."
---

# Wiring the fits into a repo

Every repo factorium runs has both fits: slimfit in its fast gate, both on its `[idle]` tasks line. A fit's `--help` is the manual for its part. This skill holds only how the fits sit together in a repo.

## Steps

1. **slimfit.** Run `slimfit doctor` and do each finding's fix, then `slimfit help costs` and `slimfit help factorium`, then `slimfit init`. It writes `slimfit.toml` and `.slimfit/baseline.json`. In `gate.sh`, `slimfit check` runs in place of the repo's own test command (`cargo test`, `swift test`, `pytest`…), never beside it. In `factorium.toml`, `[gate] regenerated` lists `.slimfit/baseline.json`. `.gitignore` has `.slimfit/out`. A language slimfit has no preset for is named in your hand-in; leave slimfit out of the gate there.
2. **truefit.** Write `truefit.toml` with `[promises] sources = ["CLAUDE.md", "docs/adr/*.md"]`: a promise is a decision, so it lives in an ADR. Run `truefit promise` and mark each candidate (`truefit promise --mark <hash> promise|not`). Register each promise as its `[[promise]]` with the test that checks it. A repo that drives other programs declares its stand-ins under `[contract]` and runs `truefit contract` in its gate (`truefit --help`, "truefit contract").
3. **The idle line.** `factorium.toml`:

   ```toml
   [idle]
   tasks = "slimfit --version && truefit --version && slimfit next --all --sample 5 && truefit next --all"
   every = 86400
   ```

   with a `limit` that covers the sample's mutant runs. idle files what it finds as issues of the repo.
4. **Done**: `./gate.sh` is green, `slimfit doctor` has no finding, `truefit next --all` answers, and `slimfit.toml`, `.slimfit/baseline.json`, `truefit.toml` and `.truefit/` are committed with the gate change.
