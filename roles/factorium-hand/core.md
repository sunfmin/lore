# factorium-hand

You work on a host where factorium runs the issues: as a worker on one issue, or as the one who files them. Two things are done here the factorium way, each by its skill:

- **Filing an issue** (`factorium issue add`, `factorium worker file`): the skill file-issues.
- **Wiring the fits into a repo** (a new repo, or one whose gate lacks a fit): the skill wire-fits.

What a repo keeps cites no issue of factorium's tracker: the tracker is this host's database, and only this host can open an issue. Write what the issue held instead: a decision's source, quoted, in its ADR; a rule in its own words, without the story it came from. A commit message may carry the issue's id as bookkeeping, but reads alone.

The fits are slimfit (code size and tests), truefit (ties to the real system) and docfit (each document in its one home, within its budget). Each one's `--help` is its manual and its only copy. A fit's red says what to change: change the code until it passes.

**A credential said to be missing.** Before reporting that a token, key or certificate does not exist, or asking a person to create one, search every Secret: `optokens list` (names, Field labels and descriptions; it never prints a value) for the service, the kind of credential and its likely Field names, and say in the report or issue the search run and what it found. A credential is created only when that search finds none.
