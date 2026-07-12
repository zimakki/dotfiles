# zimakki-html-doc skill + margin-notes design

Date: 2026-07-10
Status: approved

> Historical design record. Current skills are canonical under
> `.agents/skills/` and static links are owned by `[dotfiles]` in `mise.toml`.
> Do not use the `.claude/skills` or `setup_sim_links.zsh` paths below as current
> operating instructions.

## Problem

Zi frequently asks agents to "create an HTML document that explains X" (explainers,
plans, concept walkthroughs) because HTML is more expressive than markdown. Today
there is no structured way for his interactions with that document to flow back to
the agent — feedback means screenshots or retyped descriptions. Inspired by
[lavish-axi](https://github.com/kunchenguid/lavish-axi), but deliberately simpler:
no server, no polling. A manual copy-paste return path is acceptable.

## Solution overview

A machine-global Claude Code skill that (a) guides agents in producing
self-contained interactive HTML documents and (b) inlines a small annotation
layer, **margin-notes**, into every document. The user comments on sections or
text selections in the browser; a "Copy for agent" button aggregates all feedback
into a structured plain-text block the user pastes back into the agent session.

## Components

All live in this dotfiles repo (single entry point for machine setup):

1. **`.claude/skills/zimakki-html-doc/SKILL.md`** — the skill.
   - Triggers: "create an HTML document that explains/shows/plans …".
   - Instructs the agent to produce a **self-contained single HTML file**
     (no external assets) with stable `id`s on sections.
   - Instructs the agent to read `margin-notes.js` from the skill directory and
     inline its full contents in a `<script>` tag at the end of the document.
   - Defines the feedback output format (below) so any agent receiving pasted
     feedback can map items back to the document it wrote.
   - Leaves richer widgets (choices, sliders, toggles) to the agent's judgment
     per document, with one rule: any structured input must feed its state into
     the same aggregated copy-out.

2. **`.claude/skills/zimakki-html-doc/margin-notes.js`** — single source of
   truth for the annotation layer (JS with its CSS injected from the same file).

3. **Symlink entry** in `setup_sim_links.zsh`:
   `.claude/skills/zimakki-html-doc : ~/.claude/skills/zimakki-html-doc`
   making the skill global on every machine. Updates distribute via `git pull`
   (+ re-running the linker when files are added).

Naming: skills authored by Zi are prefixed `zimakki-` to distinguish them from
team/community skills.

## margin-notes behavior (in the browser)

- Annotatable blocks: elements marked `data-note` by the agent; fallback default
  is `section, p, h2, h3`.
- Each block gets a small 💬 affordance; clicking opens an inline comment box
  anchored to that block.
- Free text selection anywhere can also be commented; the selected quote and the
  enclosing block's `id` are captured.
- Comments persist in `localStorage`, keyed by document path — survives reloads,
  works offline and on any device, no server.
- A fixed "Feedback (n) — Copy for agent" button copies the aggregated block to
  the clipboard.

## Feedback output format

Plain text, defined by the skill:

```
## Feedback on "<document title>" (<date>)
1. [section: <id>] <comment>
2. [selection in #<id>] quoted: "<selected text>" — <comment>
```

Structured widgets append their state as additional numbered items, e.g.
`[choice: <widget-id>] selected: <value>`.

## Multi-device story

Documents are fully self-contained files — AirDrop/iCloud/email them anywhere
and the annotation layer works. Feedback copy-out is manual, so the return path
is device-independent. The skill itself reaches other machines via `git pull` of
this repo plus the symlink.

## Non-goals (for now)

- No local server, long-polling, or automatic agent round-trip (lavish-axi-style
  live loop is a possible later iteration if manual copy-paste proves annoying).
- No CDN or hosted assets; nothing published.
- No cross-device sync of the comments themselves (localStorage is per-device;
  the copied feedback text is the durable artifact).

## Error handling

- If `margin-notes.js` can't be read at generation time, the agent should say so
  and produce the document without the layer rather than fail.
- The script must be defensive in old/quirky browsers: feature-detect
  `navigator.clipboard` with a select-and-copy fallback; never break document
  rendering if the script errors (wrap init in try/catch).

## Testing

- Manual: generate a sample explainer via the skill, open in Safari and Chrome,
  add section comments and a selection comment, reload (persistence), copy out
  and verify the format.
- The skill's SKILL.md includes a short verification checklist for the agent
  (file opens standalone, widgets render, copy-out works).
