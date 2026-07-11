---
name: daftar-process-inbox
description: Classify and file photos, PDFs, voice notes, screenshots, web links, and other items from the Daftar personal HTML vault’s inbox into entities, logs, and dated assets. Use when the user says “process my inbox”, “file these”, “sort my inbox”, or “empty the inbox”, or has placed material in Daftar’s `/inbox/`.
---

# Process the Daftar inbox

Before making changes, confirm the current workspace is the Daftar HTML vault: its `AGENTS.md` must describe Daftar and `inbox/`, `_templates/`, and the category directories must exist. If the guard fails, do not mutate files; ask to run the operation from the Daftar workspace.

Read and follow the authoritative `/daftar-process-inbox` contract in `AGENTS.md` §8.1, including its classification, archiving, index, and reporting requirements.

In outline:

1. List `/inbox/` except `README.html`.
2. Read or transcribe each item and classify it.
3. Update an existing entity, create one from a template, or file a raw artifact.
4. Refresh affected dates and indexes.
5. Append one run event to `/log.html`.
6. Move processed inputs to `/inbox/.processed/YYYY-MM-DD/`.

Ask once when classification is genuinely ambiguous. Do not treat this outline as a substitute for the project contract.
