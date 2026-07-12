# zimakki-html-doc Skill + margin-notes Implementation Plan

> Historical implementation record. Current skills are canonical under
> `.agents/skills/` and static links are owned by `[dotfiles]` in `mise.toml`.
> The client-specific paths, direct-to-master policy, and legacy link-manifest
> steps below are preserved only to explain the original implementation.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A machine-global Claude Code skill that generates self-contained interactive HTML explainer documents with an inlined annotation layer (margin-notes) whose aggregated feedback the user copy-pastes back to the agent.

**Architecture:** Three artifacts in the dotfiles repo: `margin-notes.js` (vanilla JS, self-injecting CSS, localStorage persistence, clipboard copy-out), `SKILL.md` (tells any agent how to build the doc and inline the script), and a symlink entry making the skill global via `~/.claude/skills/`. No server, no build step, no dependencies.

**Tech Stack:** Vanilla ES2017 JavaScript (browser), Claude Code skill markdown, zsh symlink manifest.

## Global Constraints

- Skill directory name is exactly `zimakki-html-doc` (Zi's personal-skill prefix convention).
- Library file is exactly `.claude/skills/zimakki-html-doc/margin-notes.js`; it is the single source of truth and is **inlined** (never `src`-linked) into generated documents.
- Generated documents must be fully self-contained single HTML files (no external assets, no CDN).
- margin-notes must never break document rendering: all init wrapped in try/catch; clipboard uses `navigator.clipboard` with a `document.execCommand('copy')` fallback.
- Feedback output format (verbatim from spec):
  ```
  ## Feedback on "<document title>" (<date>)
  1. [section: <id>] <comment>
  2. [selection in #<id>] quoted: "<selected text>" — <comment>
  ```
  Structured widgets append items as `[choice: <widget-id>] selected: <value>`.
- No automated JS test harness exists in this repo; verification is `node --check` plus scripted browser verification against a fixture document (spec's "Testing" section).
- Commit directly to master (repo convention).

---

### Task 1: margin-notes.js library

**Files:**
- Create: `.claude/skills/zimakki-html-doc/margin-notes.js`

**Interfaces:**
- Consumes: nothing (self-contained browser script).
- Produces: an IIFE that, on `DOMContentLoaded` (or immediately if already loaded), decorates annotatable blocks and installs the copy-out UI. Later tasks rely on these behaviors:
  - Annotatable blocks: elements matching `[data-note]`, falling back to `section, p, h2, h3` when no `[data-note]` exists.
  - Blocks without an `id` get generated ids `mn-1`, `mn-2`, …
  - Comments persist in `localStorage` under key `margin-notes:` + `location.pathname`.
  - A fixed bottom-right button labeled `Feedback (n) — Copy for agent` copies the aggregated feedback text.
  - Global object `window.MarginNotes` with `addItem({kind, blockId, quote, text})` so agent-authored widgets can push structured items (e.g. `kind: 'choice: difficulty'`).

- [ ] **Step 1: Write the file**

```javascript
/* margin-notes v1 — inline annotation layer for agent-generated HTML documents.
 * Source of truth: dotfiles/.claude/skills/zimakki-html-doc/margin-notes.js
 * Inlined into documents by the zimakki-html-doc skill. No dependencies.
 */
(function () {
  'use strict';

  var STORE_KEY = 'margin-notes:' + location.pathname;

  var CSS = [
    '.mn-btn{position:absolute;left:-1.6em;top:0;border:none;background:none;cursor:pointer;',
    'font-size:.85em;opacity:.25;padding:0}',
    '.mn-btn:hover{opacity:1}',
    '.mn-block{position:relative}',
    '.mn-block.mn-has-note>.mn-btn{opacity:.9}',
    '.mn-box{margin:.5em 0;padding:.5em;border:1px solid #c9c9d4;border-radius:6px;',
    'background:#f7f7fb;font:14px/1.4 -apple-system,sans-serif;color:#222}',
    '.mn-box textarea{width:100%;box-sizing:border-box;min-height:3em;margin-bottom:.4em;',
    'font:inherit;padding:.3em}',
    '.mn-box .mn-quote{font-style:italic;color:#555;margin:0 0 .4em;border-left:3px solid #bbb;',
    'padding-left:.5em;white-space:pre-wrap}',
    '.mn-box button{font:inherit;margin-right:.4em;cursor:pointer}',
    '.mn-saved{font-size:13px;color:#333;margin:.2em 0;white-space:pre-wrap}',
    '.mn-saved .mn-del{color:#a33;cursor:pointer;border:none;background:none;font:inherit}',
    '#mn-copy{position:fixed;right:16px;bottom:16px;z-index:9999;padding:.6em 1em;',
    'border-radius:999px;border:1px solid #888;background:#1f1f2e;color:#fff;cursor:pointer;',
    'font:14px -apple-system,sans-serif;box-shadow:0 2px 8px rgba(0,0,0,.25)}',
    '#mn-sel{position:absolute;z-index:9998;padding:.2em .6em;border-radius:6px;border:1px solid #888;',
    'background:#1f1f2e;color:#fff;cursor:pointer;font:13px -apple-system,sans-serif}'
  ].join('\n');

  function load() {
    try { return JSON.parse(localStorage.getItem(STORE_KEY)) || []; }
    catch (e) { return []; }
  }
  function save(items) {
    try { localStorage.setItem(STORE_KEY, JSON.stringify(items)); } catch (e) {}
  }

  var items = load();
  var copyBtn;

  function addItem(item) {
    item.ts = new Date().toISOString();
    items.push(item);
    save(items);
    refresh();
  }

  function removeItem(idx) {
    items.splice(idx, 1);
    save(items);
    refresh();
  }

  function feedbackText() {
    var title = document.title || location.pathname;
    var date = new Date().toISOString().slice(0, 10);
    var lines = ['## Feedback on "' + title + '" (' + date + ')'];
    items.forEach(function (it, i) {
      var n = (i + 1) + '. ';
      if (it.kind === 'selection') {
        lines.push(n + '[selection in #' + it.blockId + '] quoted: "' + it.quote + '" — ' + it.text);
      } else if (it.kind === 'section') {
        lines.push(n + '[section: ' + it.blockId + '] ' + it.text);
      } else {
        lines.push(n + '[' + it.kind + '] ' + it.text);
      }
    });
    return lines.join('\n');
  }

  function copy(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }
    var ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch (e) {}
    document.body.removeChild(ta);
    return Promise.resolve();
  }

  function refresh() {
    if (copyBtn) copyBtn.textContent = 'Feedback (' + items.length + ') — Copy for agent';
    document.querySelectorAll('.mn-block').forEach(function (b) {
      var has = items.some(function (it) { return it.blockId === b.id; });
      b.classList.toggle('mn-has-note', has);
    });
  }

  function commentBox(blockId, quote, onDone) {
    var box = document.createElement('div');
    box.className = 'mn-box';
    if (quote) {
      var q = document.createElement('p');
      q.className = 'mn-quote';
      q.textContent = quote;
      box.appendChild(q);
    }
    var saved = items
      .map(function (it, i) { return { it: it, i: i }; })
      .filter(function (e) { return e.it.blockId === blockId && (!quote || e.it.quote === quote); });
    saved.forEach(function (e) {
      var p = document.createElement('p');
      p.className = 'mn-saved';
      p.textContent = '💬 ' + e.it.text + ' ';
      var del = document.createElement('button');
      del.className = 'mn-del';
      del.textContent = '[delete]';
      del.onclick = function () { removeItem(e.i); box.remove(); };
      p.appendChild(del);
      box.appendChild(p);
    });
    var ta = document.createElement('textarea');
    ta.placeholder = 'Comment for the agent…';
    box.appendChild(ta);
    var ok = document.createElement('button');
    ok.textContent = 'Save';
    ok.onclick = function () {
      if (ta.value.trim()) {
        addItem({ kind: quote ? 'selection' : 'section', blockId: blockId, quote: quote || '', text: ta.value.trim() });
      }
      box.remove();
      if (onDone) onDone();
    };
    var cancel = document.createElement('button');
    cancel.textContent = 'Cancel';
    cancel.onclick = function () { box.remove(); if (onDone) onDone(); };
    box.appendChild(ok);
    box.appendChild(cancel);
    return box;
  }

  function decorateBlocks() {
    var blocks = document.querySelectorAll('[data-note]');
    if (!blocks.length) blocks = document.querySelectorAll('section, p, h2, h3');
    var n = 0;
    blocks.forEach(function (b) {
      if (b.closest('.mn-box') || b.id === 'mn-copy') return;
      if (!b.id) b.id = 'mn-' + (++n);
      b.classList.add('mn-block');
      var btn = document.createElement('button');
      btn.className = 'mn-btn';
      btn.textContent = '💬';
      btn.title = 'Comment on this block';
      btn.onclick = function (ev) {
        ev.stopPropagation();
        var existing = b.querySelector('.mn-box');
        if (existing) { existing.remove(); return; }
        b.appendChild(commentBox(b.id, null));
        b.querySelector('.mn-box textarea').focus();
      };
      b.insertBefore(btn, b.firstChild);
    });
  }

  var selBtn;
  function watchSelection() {
    document.addEventListener('mouseup', function () {
      setTimeout(function () {
        if (selBtn) { selBtn.remove(); selBtn = null; }
        var sel = window.getSelection();
        var text = sel ? String(sel).trim() : '';
        if (!text || text.length < 3) return;
        var node = sel.anchorNode && sel.anchorNode.parentElement;
        var block = node && node.closest('.mn-block');
        if (!block || node.closest('.mn-box')) return;
        var rect = sel.getRangeAt(0).getBoundingClientRect();
        selBtn = document.createElement('button');
        selBtn.id = 'mn-sel';
        selBtn.textContent = '💬 Comment on selection';
        selBtn.style.left = (window.scrollX + rect.left) + 'px';
        selBtn.style.top = (window.scrollY + rect.bottom + 6) + 'px';
        selBtn.onclick = function () {
          var box = commentBox(block.id, text);
          block.appendChild(box);
          box.querySelector('textarea').focus();
          selBtn.remove();
          selBtn = null;
        };
        document.body.appendChild(selBtn);
      }, 0);
    });
  }

  function installCopyButton() {
    copyBtn = document.createElement('button');
    copyBtn.id = 'mn-copy';
    copyBtn.onclick = function () {
      copy(feedbackText()).then(function () {
        var old = copyBtn.textContent;
        copyBtn.textContent = 'Copied ✓';
        setTimeout(function () { copyBtn.textContent = old; refresh(); }, 1200);
      });
    };
    document.body.appendChild(copyBtn);
  }

  function init() {
    try {
      var style = document.createElement('style');
      style.textContent = CSS;
      document.head.appendChild(style);
      decorateBlocks();
      installCopyButton();
      watchSelection();
      refresh();
      window.MarginNotes = { addItem: addItem, items: items, feedbackText: feedbackText };
    } catch (e) {
      if (window.console) console.error('margin-notes failed to init:', e);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
```

- [ ] **Step 2: Syntax-check the file**

Run: `node --check .claude/skills/zimakki-html-doc/margin-notes.js`
Expected: no output, exit code 0.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/zimakki-html-doc/margin-notes.js
git commit -m "feat(html-doc): add margin-notes annotation library"
```

---

### Task 2: Fixture document + browser verification

**Files:**
- Create: `.claude/skills/zimakki-html-doc/fixture.html` (checked in; doubles as a living example of a generated document)

**Interfaces:**
- Consumes: `margin-notes.js` from Task 1 (inlined into the fixture, exactly as the skill will instruct agents to do).
- Produces: a known-good reference document for future manual regression checks.

- [ ] **Step 1: Write the fixture**

Create `fixture.html` with this structure, replacing `/* INLINE margin-notes.js HERE */` with the full contents of `margin-notes.js` (this mirrors what the skill instructs agents to do — build the fixture with a script or manual paste, do not `src`-link):

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>margin-notes fixture</title>
<style>
  body { font: 16px/1.6 -apple-system, sans-serif; max-width: 42em; margin: 2em auto; padding: 0 3em; }
</style>
</head>
<body>
<h1>margin-notes fixture</h1>
<section data-note id="intro">
  <h2>Introduction</h2>
  <p>This section exists to verify block-level commenting on an element with an explicit id.</p>
</section>
<section data-note>
  <h2>Auto-id section</h2>
  <p>This section has no id and must receive a generated one (mn-1).</p>
</section>
<script>
/* INLINE margin-notes.js HERE */
</script>
</body>
</html>
```

Build command (from repo root):

```bash
cd .claude/skills/zimakki-html-doc
python3 - <<'EOF'
from pathlib import Path
tpl = Path('fixture.html').read_text()
js = Path('margin-notes.js').read_text()
Path('fixture.html').write_text(tpl.replace('/* INLINE margin-notes.js HERE */', js))
EOF
```

- [ ] **Step 2: Verify in a real browser**

Open the fixture (`open .claude/skills/zimakki-html-doc/fixture.html`) — or drive it with browser automation tools if available — and confirm each of:

1. Both sections show a 💬 affordance; clicking opens a comment box; saving a comment updates the button to `Feedback (1) — Copy for agent`.
2. The no-id section received id `mn-1` (inspect or comment on it and check copy-out references `mn-1`).
3. Selecting text inside a section shows the "Comment on selection" button; saving records a selection item.
4. Reloading the page keeps the count (localStorage persistence).
5. "Copy for agent" puts text on the clipboard matching:
   ```
   ## Feedback on "margin-notes fixture" (<today>)
   1. [section: intro] <comment>
   2. [selection in #mn-1] quoted: "<selected text>" — <comment>
   ```
6. The page renders normally with JS console showing no uncaught errors.

Expected: all six pass. If any fail, fix `margin-notes.js`, rebuild the fixture (Step 1 command), re-verify.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/zimakki-html-doc/fixture.html
git commit -m "feat(html-doc): add margin-notes fixture/example document"
```

---

### Task 3: SKILL.md

**Files:**
- Create: `.claude/skills/zimakki-html-doc/SKILL.md`

**Interfaces:**
- Consumes: `margin-notes.js` (referenced by relative path from the skill's base directory), `fixture.html` (pointed to as an example).
- Produces: the skill contract other agents follow, including the feedback format the user will paste back.

- [ ] **Step 1: Write the skill**

```markdown
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
  whenever its value changes (remove the previous item for the same widget first
  by filtering `MarginNotes.items` if you want latest-only semantics).

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
```

- [ ] **Step 2: Verify skill loads**

Run: `head -5 .claude/skills/zimakki-html-doc/SKILL.md`
Expected: frontmatter with `name: zimakki-html-doc`. (In an interactive Claude Code session in this repo, the skill should appear in the available-skills list on next start.)

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/zimakki-html-doc/SKILL.md
git commit -m "feat(html-doc): add zimakki-html-doc skill"
```

---

### Task 4: Make the skill machine-global via symlink

**Files:**
- Modify: `setup_sim_links.zsh` (LINKS manifest, around line 12-31)

**Interfaces:**
- Consumes: the skill directory from Tasks 1-3.
- Produces: `~/.claude/skills/zimakki-html-doc` symlink on every machine that runs the linker.

- [ ] **Step 1: Add the manifest entry**

In `setup_sim_links.zsh`, add to the `LINKS` array (directory links are already supported — see the `television` entry):

```zsh
  ".claude/skills/zimakki-html-doc:~/.claude/skills/zimakki-html-doc"
```

- [ ] **Step 2: Run the linker and verify**

```bash
./setup_sim_links.zsh
ls -l ~/.claude/skills/zimakki-html-doc
```

Expected: linker prints `✓ /Users/zimakki/.claude/skills/zimakki-html-doc → …/dotfiles/.claude/skills/zimakki-html-doc`; `ls -l` shows the symlink resolving into the repo, and `SKILL.md`, `margin-notes.js`, `fixture.html` are visible through it.

- [ ] **Step 3: Commit**

```bash
git add setup_sim_links.zsh
git commit -m "feat(html-doc): symlink zimakki-html-doc skill into ~/.claude/skills"
```

---

### Task 5: End-to-end check

**Files:**
- None created in-repo (generates a throwaway document under `/tmp`).

**Interfaces:**
- Consumes: the globally-linked skill from Task 4.

- [ ] **Step 1: Generate a real document following the skill**

Acting exactly as a consuming agent would: read `~/.claude/skills/zimakki-html-doc/SKILL.md`, then create `/tmp/genserver-explainer.html` — a short 3-section explainer on any topic, with `data-note` section ids and margin-notes.js inlined per the skill's instructions.

- [ ] **Step 2: Verify the round trip**

Open it in a browser, add one section comment and one selection comment, click "Copy for agent", and confirm the clipboard content matches the skill's documented format with the correct section ids. Expected: format matches; ids map to the sections you authored.

- [ ] **Step 3: Report**

No commit. Report the verification result to the user, including the copied feedback block as evidence.
