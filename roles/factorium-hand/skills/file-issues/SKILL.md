---
name: file-issues
description: "Use before filing an issue on factorium's tracker (`factorium issue add`, `factorium worker file`): one issue per thing that lands on its own, blocks only for code order with their why, given at filing, and the body a worker can act on alone."
---

# Filing issues for factorium

An issue is ready the moment it is filed, and a worker takes it on the next tick. So it is complete when you file it: its blocks, its words, its acceptance. Nothing is added after.

## Steps

1. **Read the target.** The repo must be on `factorium checkout list`; one that is not has no worker, so say so instead of filing. `git fetch`, read the code at `origin/<proving>` (`git show`, `git grep`), and start the body with `Based on <checkout> origin/<proving> <commit>.`. Use the words of the repo's `GLOSSARY.md` and keep to its `docs/adr/`.
2. **Split.** One issue is one thing that can be accepted on its own. When the acceptance lists several things that could each land alone, they are several issues, blocked in their order (truefit#8 put five in one and ran 70 minutes into a conflict). Prefactoring goes first, in an issue of its own.
3. **Find the real blocks.** Read the checkout's open issues (`factorium issue list <checkout>`). Block on one only when this issue needs its result in the code, or when both change the same code: the same command, the same output, the same module, whether or not either body names a file (truefit#11 and #8 both changed `truefit sim`'s output). Each block carries its `--why`: what it needs from that issue. A block on another checkout is `<checkout>#N`; on its release and install, `<checkout>#N@cut`.
4. **Keep blocks for code.** A thing only one can use at a time (a phone, a host) is a factorium resource (`worker hold`, `worker exclusive --resource`), never a block: a block holds back the whole issue, code included (rollmind, 2026-11-24). An issue that only measures (a soak, a bench, a run on a device) blocks no issue that changes code. A soft dependency ("better with it, fine without") gets no block: the body says "use it if it has landed, do not wait for it".
5. **Write the body.** What was seen, with its evidence (a command and what it printed, a file and line, an issue). What to do. Its acceptance as checkable lines. Measurements the work makes go in a comment on the issue ("post in a comment here"), never into an ADR or a README. A decision you made while filing goes in the body as a Decided record:

   ```
   Decided (<who>, for <owner>): <what>
   Options: <the real ones>
   Chose: <which>, because <why>
   Undo: <how>
   ```

6. **File it with its blocks in one call**: `factorium issue add <checkout> <title> --body-file - [--blocked-by <n> --why <why>]…` (a worker: `factorium worker file …`). A block added later comes after a worker may already have started. An issue never waits for a person to be ready: to keep a worker off it, block it. Only spending money, or a step only the owner's own hand can do, is filed `--waiting-for-human`; a worker escalates those instead (`factorium worker escalate`).
7. **Check what was filed**: `factorium issue show <checkout> <n>` answers its status and `blocked_by` as you meant them. Report each as `<checkout>#<n>` with that status.

A large migration that deletes an old implementation is blocked by an issue for every part of the old one's behaviour, so nothing is deleted before its replacement lands.
