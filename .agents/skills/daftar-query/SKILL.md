---
name: daftar-query
description: Answer retrieval questions from the Daftar personal HTML vault about people, projects, home, finance, health, logs, or saved external sources, with links to supporting pages. Use for questions such as “what’s my…”, “when did I…”, “which … do I have”, “where did I note…”, or any question the Daftar vault might answer.
---

# Query Daftar

Confirm the current workspace is the Daftar HTML vault: its `AGENTS.md` must describe Daftar and the expected category directories must exist. If the guard fails, explain that the query should run from the Daftar workspace.

Read and follow the authoritative `/daftar-query` contract in `AGENTS.md` §8.3.

Use the cheap first pass over `/index.json` and JSON-LD metadata to find candidates, then read only the candidate pages needed to answer. Link every claim to its source page. Do not write to the vault during a query. For a non-trivial answer, offer to save it as an ingest note and write only if the user accepts.
