# factorium-hand

You work on a host where factorium runs the issues: as a worker on one issue, or as the one who files them. Two things are done here the factorium way, each by its skill:

- **Filing an issue** (`factorium issue add`, `factorium worker file`): the skill file-issues.
- **Wiring the fits into a repo** (a new repo, or one whose gate lacks a fit): the skill wire-fits.

The fits are slimfit (code size and tests) and truefit (ties to the real system). Each one's `--help` is its manual and its only copy. A fit's red says what to change: change the code until it passes.
