---
name: zimakki-html-doc
description: Create a self-contained interactive HTML document (explainer, plan, concept walkthrough) with an inlined annotation layer so the user can comment on sections/selections in the browser and paste aggregated feedback back to the agent. Use whenever the user asks to "create an HTML document/page that explains/shows/plans" something.
---

# zimakki-html-doc

Produce a **single self-contained HTML file** — all CSS and JS inline, no external
assets, no CDN — so the document works offline and on any device.

## Design (house style)

Start from `template.html` in this skill's directory: copy its full `<style>`
block and page structure, replace the content sections. It is the Catppuccin
Mocha house style, matching the machine's bat/ghostty/starship/atuin setup.

- **Typography** — Charter serif for prose (18px/1.7, 48rem measure); SF Mono
  for everything structural. Headings show dimmed markdown `#`/`##` prefixes and
  a per-level color ramp (h1 mauve, h2 blue, h3 green, h4 yellow). All fonts are
  system-resident; never fetch a webfont.
- **Laptop-first layout** — ≥84rem the page goes asymmetric like a docs site:
  the contents rail sits in the left margin, the content column leans
  left-of-center, and code/diagram panes grow rightward from the prose edge (to
  60rem). Keep this; don't re-center the column on laptop widths.
- **Contents rail** — the template's first inline script auto-builds the fixed
  left-hand "contents" nav from `data-note` sections (shown ≥84rem, scroll-spy
  highlights the current section). Keep the script as-is; it needs no per-document
  maintenance.
- **Margin anchors** — on wide screens each `data-note` section displays its own
  `#id` in the left margin, so ids double as visible feedback anchors. Choose
  ids that read well there.
- **Code** — `<pre class="code" data-lang="...">`, syntax colored by hand with
  the template's `.tk-*` classes (Catppuccin mapping: `tk-kw` keywords/mauve,
  `tk-fn` functions/blue, `tk-str` strings/green, `tk-num` numbers/peach,
  `tk-type` types/yellow, `tk-cm` comments, `tk-op` operators, `tk-pr`
  properties, `tk-pmt` shell prompt, `tk-out` command output). No highlighter
  library — hand-applied spans keep the file tiny and dependency-free.
- **Diagrams (optional)** — author Mermaid source inside
  `<figure class="diagram"><pre class="mermaid">…</pre></figure>`. If — and only
  if — the document contains a diagram, fetch
  `https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js` at generation
  time (~3.4 MB) and inline it before `</body>`, followed by the
  `mermaid.initialize` block kept as a comment at the bottom of `template.html`.
  The viewed document never touches the network; without the renderer the
  diagram source degrades to readable text in the same pane. For color, define
  one `classDef` per Catppuccin accent inside the diagram source
  (`classDef mauve stroke:#cba6f7,color:#cba6f7,fill:#313244`, etc. — see the
  template's flowchart) and assign classes so colors carry meaning per node.
- **Annotation theming** — margin-notes.js reads `--mn-*` CSS variables
  (declared in the template's `:root`); keep them when adapting the style so
  the comment UI stays Mocha-native.

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

**Known caveat — Safari + `file://`:** some browsers (notably Safari) treat each
`file://` document as a unique, sandboxed security origin, which can silently break
`localStorage`. margin-notes.js detects this at load and shows an inline warning
banner instead of failing silently — comments still work for the current session,
they just won't survive a reload. If a user reports losing feedback after
reloading, tell them to copy their feedback before closing the tab, or open the
file via a local server (e.g. `python3 -m http.server`) for full persistence.

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

See `template.html` in this directory for the styled reference document, and
`fixture.html` for the minimal known-good regression example.
