---
name: roles
description: "Use when a worker needs a role it lacks, a checkout's default role changes, an issue needs a role other than its checkout's, or the role library changes: compose role directories with rolesmith and point factorium at them."
---

# Roles for factorium's workers

The roles workers play live in the rolesmith library this host reads (`rolesmith source list`). A change to a role is a pull request to that library, merged once `rolesmith check` passes (`rolesmith propose`). Another host's library is not touched from here.

## Role directories

- A worker plays one or more roles. Each combination is a directory `~/.local/share/roles/<dir>/`, made by `rolesmith use <role>… --into claude-code --project <dir>`, its versions pinned in that directory's `rolesmith.toml`. Name it by the kind of work it does (`rust-cli`, `ios-private-ml-app`), never by the project that first uses it (`rolesmith help composing`).
- A role every agent of a kind needs is in that role's `requires`, never listed again in a directory. A role only some projects want (a real phone, for example) is installed only into the directories that want it.
- A changed combination is a new directory. The old one is removed only after every worker started from it has ended.

## Pointing factorium at a role

- A checkout whose work is mostly of one kind gets a default: `factorium checkout edit <checkout> --role ~/.local/share/roles/<dir>`. `factorium checkout list` is the record of each checkout's role.
- An issue whose work is of another kind names its own: `factorium issue add … --role <dir>`, or `factorium issue edit … --role <dir>` once filed. Choose by the work the issue does, not by the stage it belongs to. `factorium issue show` answers `role_from`: the issue or its checkout.

## A new version of the library

`rolesmith source update <source> && rolesmith update --project ~/.local/share/roles/<dir>` for each directory. Workers started after that read the new version.
