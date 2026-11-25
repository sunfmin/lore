# lore

A rolesmith library: each role is `roles/<role>/` (`role.toml`, `core.md`, `prohibitions.toml`, `skills/`), each program a role runs is `tools/<tool>/tool.toml`. `rolesmith --help` and its topics are the manual for that shape; `./gate.sh` (`rolesmith check`) is done. Everything here is read by agents: write it with the skill writing-for-agents.

## Agent skills

### Issue tracker

Issues live in factorium's local tracker (`factorium issue … lore`). See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context. See `docs/agents/domain.md`.
