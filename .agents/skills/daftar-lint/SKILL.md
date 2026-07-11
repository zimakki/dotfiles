---
name: daftar-lint
description: Audit and safely repair integrity problems in the Daftar personal HTML vault, including JSON-LD, links, backlinks, dates, scripts, indexes, orphans, stale entities, and contradictions. Use weekly, before large Daftar changes, or when the user says “lint”, “check the vault”, “audit the vault”, “find broken links”, or “refresh backlinks”.
---

# Lint Daftar

Before making changes, confirm the current workspace is the Daftar HTML vault: its `AGENTS.md` must describe Daftar and the expected category directories must exist. If the guard fails, do not mutate files; ask to run the operation from the Daftar workspace.

Read and follow the authoritative `/daftar-lint` contract and action table in `AGENTS.md` §8.4. The table determines which findings to repair automatically and which to surface for a user decision.

Run all independent checks in parallel where practical. Rebuild backlinks only from JSON-LD `relations`; never invent them by hand. Regenerate `/index.json` and append the required structured lint event to `/log.html` after the checks.

Do not treat this orientation as a substitute for the project contract.
