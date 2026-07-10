---
name: zimakki-html-doc
description: Create a self-contained interactive HTML document (explainer, plan, concept walkthrough) with an inlined annotation layer so the user can comment on sections/selections in the browser and paste aggregated feedback back to the agent. Use whenever the user asks to "create an HTML document/page that explains/shows/plans" something.
---

# zimakki-html-doc

Produce a **single self-contained HTML file** — all CSS and JS inline, no external
assets, no CDN — so the document works offline and on any device.

## Document structure

- Wrap each logical unit of content in `<section data-note id="kebab-case-id">`.
  Stable, descriptive ids matter: the user's feedback references them and you
  will use them to locate what to edit.
- Give the document a meaningful `<title>` — it appears in the feedback header.
- Richer widgets (choice buttons, sliders, toggles) are at your discretion per
  document. One rule: any structured input must report its state into the
  feedback aggregation by calling
  `MarginNotes.addItem({kind: 'choice: <widget-id>', blockId: '<section-id>', text: 'selected: <value>'})`
  whenever its value changes (if you want latest-only semantics, first find the
  index of the previous item for that widget in `MarginNotes.items` — e.g. via
  `findIndex` — and call `MarginNotes.removeItem(index)` before calling `addItem`
  with the new value).

## Annotation layer (required)

Read `margin-notes.js` in this skill's directory and inline its **full contents**
in a `<script>` tag at the end of `<body>`. Never link it by path or URL — the
document must stay portable. If the file cannot be read, tell the user and
generate the document without the layer rather than failing.

This gives the user: a 💬 comment affordance per section, comment-on-text-selection,
localStorage persistence, and a "Feedback (n) — Copy for agent" button.

## Feedback round-trip

The user will paste feedback in this format; each item names a section id in the
document you wrote — edit those locations precisely:

    ## Feedback on "<document title>" (<date>)
    1. [section: <id>] <comment>
    2. [selection in #<id>] quoted: "<selected text>" — <comment>
    3. [choice: <widget-id>] selected: <value>

## Verification checklist (before telling the user it's done)

- [ ] File opens standalone (`open <file>.html`) with no console errors.
- [ ] 💬 affordances appear on every `data-note` section.
- [ ] "Feedback (0) — Copy for agent" button is visible bottom-right.
- [ ] Any custom widgets you added push items via `MarginNotes.addItem`.

See `fixture.html` in this directory for a known-good example.
