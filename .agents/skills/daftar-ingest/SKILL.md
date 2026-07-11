---
name: daftar-ingest
description: Ingest an external URL, file, article, book, podcast, or other consumed source into the Daftar personal HTML vault, synthesize notes, and cross-link related entities. Use when the user says “ingest this”, “save this to the vault”, “add this article/book/podcast”, or otherwise wants external material captured in Daftar.
---

# Ingest into Daftar

Before making changes, confirm the current workspace is the Daftar HTML vault: its `AGENTS.md` must describe Daftar and the category directories such as `ingest/`, `people/`, and `projects/` must exist. If the guard fails, do not mutate files; ask to run the operation from the Daftar workspace.

Read and follow the authoritative `/daftar-ingest` contract in `AGENTS.md` §8.2. The project manual owns the current schema and workflow.

In outline:

1. Read or transcribe the source.
2. Discuss the takeaways briefly and ask what is most worth capturing.
3. Create `/ingest/YYYY-MM-DD-<slug>.html` from `/_templates/ingest.html`.
4. Cross-link every mentioned existing entity in JSON-LD and visible HTML.
5. Update `/ingest/index.html`, append to `/log.html`, and regenerate `/index.json`.

Do not treat this outline as a substitute for the project contract.
