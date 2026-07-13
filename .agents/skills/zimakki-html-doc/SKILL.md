---
name: zimakki-html-doc
description: Create a self-contained, infographic-first interactive HTML decision brief, explainer, plan, review, or concept walkthrough with linked deep dives and an inlined annotation layer. Use whenever the user asks for an HTML document or page that explains, shows, compares, reviews, or plans something, especially when visual structure or explicit decisions would help.
---

# zimakki-html-doc

Produce a **single self-contained HTML file** that shows the shape of the issue
before asking the user to read the detail. Keep all CSS and JS inline, with no
external assets or CDN, so the document works offline and on any device.

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

## Default information architecture

Build the page in this order:

1. Title and a one-sentence purpose.
2. **Decisions needed**, when unresolved choices exist. Put every unresolved
   decision here, ordered by blocking importance or impact. Mark a recommendation
   when one exists, but never preselect it for the user. Do not mix in settled
   outcomes, recommendations that need no approval, or implementation tasks.
3. **At a glance**, using one strong visual overview. If there are no decisions,
   make this the first section after the title.
4. Linked detail sections containing evidence, caveats, and reasoning.

Do not reveal a new decision only in a later section: also surface it in the
top decision dashboard. For a large set, group cards by theme while keeping all
of them visible near the top.

Every decision card and meaningful visual node should link to a stable detail
anchor such as `#detail-storage-model`; the detail section should link back to
the overview. Keep these deep dives in the same file so navigation, offline use,
and annotation continue to work.

## Visual-first explanation

Prefer a visual form whenever it communicates a real relationship faster than
prose:

| Information | Preferred form |
| --- | --- |
| Process, lifecycle, cause/effect | flow or dependency chain |
| Events, rollout, state changes | timeline |
| Competing options | comparison cards or matrix |
| System structure or ownership | architecture map or tree |
| Risks, priorities, status | impact/status board |
| Real quantities | bars or proportional chart |
| Several key facts | metric strip or annotated cards |

Use the reusable patterns in `template.html`. Prefer semantic HTML and CSS for
cards, grids, timelines, and small flows; use inline SVG for bespoke diagrams.
Use Mermaid only for relationship-heavy diagrams that would be substantially
harder to author directly. A visual overview is required unless the material
has no honest visual structure; in that case use a concise set of structured
summary cards instead of inventing a chart.

Keep visuals informational rather than decorative:

- Use charts only for real quantities; never imply invented precision.
- Make color reinforce meaning, and repeat the meaning with text, shape, or
  position so color is never the only signal.
- Keep visual labels short and move nuance into linked detail sections.
- Add an accessible label or caption to every diagram and meaningful visual.
- Prefer one coherent overview over a collection of unrelated widgets.
- Preserve clean stacking and reading order on narrow screens.

## Document and decision markup

- Wrap each logical unit of content in `<section data-note id="kebab-case-id">`.
  Stable, descriptive ids matter: the user's feedback references them and you
  will use them to locate what to edit.
- Give the document a meaningful `<title>` — it appears in the feedback header.
- Use the template's declarative choice markup for decisions. Put
  `data-choice="<stable-widget-id>"` on the option container and
  `data-choice-option="<stable-value>"` on each button. Add
  `data-recommended` to the recommended option for presentation only. The
  inlined annotation layer binds these buttons, restores saved state, and keeps
  only the latest selection in feedback.
- For other structured widgets, call `MarginNotes.addItem(...)` so their state
  appears in copied feedback; use stable widget and section identifiers.

## Annotation layer (required)

Read `margin-notes.js` in this skill's directory and inline its **full contents**
in a `<script>` tag at the end of `<body>`. Never link it by path or URL — the
document must stay portable. If the file cannot be read, tell the user and
generate the document without the layer rather than failing.

This gives the user: a 💬 comment affordance per section, comment-on-text-selection,
declarative decision choices, localStorage persistence, and a
"Feedback (n) — Copy for agent" button.

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
- [ ] Unresolved decisions are grouped at the top; no later decision is absent
      from that dashboard.
- [ ] The visual overview precedes detailed prose and links to stable deep dives.
- [ ] Visuals retain their meaning and reading order at narrow widths.
- [ ] 💬 affordances appear on every `data-note` section.
- [ ] "Feedback (0) — Copy for agent" button is visible bottom-right.
- [ ] Decision choices select visibly, restore on reload, replace the previous
      selection for that decision, and appear in copied feedback.
- [ ] Any other custom widgets push items via `MarginNotes.addItem`.

See `template.html` in this directory for the styled reference document, and
`fixture.html` for the minimal known-good regression example.
