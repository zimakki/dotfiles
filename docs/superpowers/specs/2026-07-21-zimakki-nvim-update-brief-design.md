# zimakki-nvim-update-brief design

Date: 2026-07-21  
Status: Approved

## Purpose

Create a personal Codex skill named `zimakki-nvim-update-brief` that explains
what is newly possible across the user's Neovim stack. The skill runs outside
Neovim, does not update Neovim, and produces a curated, self-contained HTML
learning brief.

The brief is intentionally not an upgrade audit or changelog mirror. Its job is
to help the user notice new workflows, capabilities, and useful opt-in features
soon after they become available.

## Goals

- Inspect changes relevant to the active AstroNvim configuration without
  changing configuration, lockfiles, installed plugin revisions, or Mason
  packages.
- Explain what new capabilities enable and why they may matter to the user's
  workflow.
- Feature no more than three to seven strong discoveries per report.
- Focus primarily on already-installed plugins and Mason tools.
- Include at most one or two exceptional adjacent discoveries when they are
  directly relevant to the user's stack.
- Remember what earlier reports covered so updates are not missed when the user
  runs an updater first, and stories are not repeated later.
- Use a dedicated subagent with `zimakki-html-doc` to create the final
  interactive HTML document.
- Prefer primary, authoritative evidence and omit claims that cannot be
  supported confidently.

## Non-goals

- Apply, select, roll back, or recommend automatic updates.
- Modify Neovim configuration or suggest unsolicited configuration edits.
- Provide exhaustive release-note coverage.
- Explain routine bug fixes, dependency bumps, refactors, or maintenance in
  detail.
- Produce a risk-heavy upgrade or compatibility audit.
- Become a general Neovim news or plugin-trending feed.
- Run continuously or on a schedule in the first version.

## Invocation and location

The skill is invoked as:

```text
/zimakki-nvim-update-brief
```

An optional configuration path may be supplied to inspect a non-active setup.
Without one, the skill resolves the active configuration from
`NVIM_APPNAME`, falling back to `~/.config/nvim`.

The managed skill source will live at:

```text
.agents/skills/zimakki-nvim-update-brief/
```

inside the dotfiles repository.

Persistent reports and coverage history will live outside Neovim at:

```text
~/.local/share/zimakki-nvim-update-brief/
├── state.json
└── reports/
    └── YYYY-MM-DD-HHMM-whats-new.html
```

## Architecture

The hybrid design separates factual collection from editorial interpretation
and visual presentation:

```text
active config + prior coverage
            |
            v
   read-only collector
            |
            v
 structured candidate manifest
            |
            v
 research and editorial curation
            |
            v
  evidence bundle + visual assets
            |
            v
 zimakki-html-doc subagent
            |
            v
 verified HTML report + new coverage state
```

### 1. Skill orchestrator

`SKILL.md` owns the end-to-end workflow and its editorial policy. It:

1. Resolves the target configuration.
2. Runs the deterministic collector.
3. Groups candidates into research themes.
4. Researches candidates, using parallel research subagents when the candidate
   set is large enough to benefit.
5. Selects the strongest three to seven discoveries.
6. Prepares a structured evidence bundle.
7. Launches a dedicated subagent that must use `zimakki-html-doc`.
8. Verifies the resulting report and its read-only guarantees.
9. Advances coverage state only for successfully covered components.

The orchestrator remains capable of doing the research itself when parallel
agents are unavailable. The HTML assembly step remains a distinct subagent
boundary when agent support is available.

### 2. Read-only collector

A deterministic script collects facts that should not depend on model
interpretation:

- Resolved configuration path and `NVIM_APPNAME`.
- Current `lazy-lock.json` plugin names, branches, and revisions.
- Installed plugin repository remotes and revisions.
- Relevant Lazy version, branch, and pin metadata.
- Installed Mason package names, versions, receipts, and upstream projects.
- The last successfully covered upstream revision for each component.
- Compatible upstream releases, tags, or branch revisions available now.

The collector may read local metadata and make network queries to remote Git
repositories, GitHub APIs, Mason registry sources, and official project
endpoints. It must not invoke Lazy sync/update/install, Mason update/install, or
checkout changes into installed repositories.

Its output is a structured candidate manifest in a temporary working
directory. The manifest includes source identity, installed revision, coverage
baseline, candidate target, version constraints, comparison URLs, and any
collection warnings.

### 3. Coverage baseline

Coverage is tracked per component, not with one global timestamp.

On the first run, the baseline is normally the currently installed or locked
revision. If a prior lock revision is safely recoverable from local Git history,
the collector may include it as a clearly identified initial safety window.

On later runs:

- If the user has not updated, compare the last covered upstream revision with
  the newest compatible target.
- If the user updated before running the skill, still compare the last covered
  revision with the current/newest target.
- If a target was already covered but is not yet installed, do not repeat its
  story.
- If history diverges because of a force-push, repository replacement, or
  incompatible version line, do not guess. Mark the component unresolved and
  retain its prior coverage state.

A component advances only when its candidate range has either been deliberately
covered in the report or deliberately classified as having no learning value.
A component that could not be inspected remains pending for the next run.

### 4. Research and curation

Research uses primary sources wherever possible:

- Official release notes and changelogs.
- Official documentation and migration guides.
- Upstream commits and pull requests.
- Maintainer-provided examples, screenshots, and demonstrations.

Changelog prose is evidence, not publishable copy. Research must translate it
into:

- What is newly possible?
- Why is it interesting?
- Which workflow does it improve or create?
- How does it relate to this specific Neovim configuration?
- Is it automatic, available after an update, or opt-in?
- What is the smallest useful way to try or understand it?

Candidates rank highly when they enable a new workflow, are user-visible and
testable, fit the user's installed plugins or development languages, have
strong evidence, and have not appeared in a prior report.

Routine fixes, dependency bumps, internal refactors, performance work without a
meaningful workflow effect, and repetitive maintenance are discarded or
counted only in a collapsed summary.

The adjacent-discovery threshold is deliberately high. An uninstalled plugin or
Mason tool appears only when current research reveals a strong and direct fit
with the existing stack. The section contains at most two items and is omitted
when nothing qualifies.

### 5. Evidence bundle

The orchestrator passes the HTML subagent a bounded bundle rather than raw
research. For every selected discovery it contains:

- A concise capability statement.
- The user benefit and local relevance.
- A short try-it workflow or focused example.
- Required update or opt-in status.
- Primary source URLs and the exact evidence each supports.
- Approved screenshots or local visual assets, with source attribution.
- Suggested diagram content when a workflow is better explained visually.
- Any short caveat necessary to understand the feature.

It also includes the coverage period, smaller user-visible improvements,
collapsed maintenance counts, exceptional adjacent discoveries, and collection
gaps.

### 6. HTML-document subagent

The final assembly is delegated to a dedicated subagent whose prompt explicitly
requires use of `zimakki-html-doc`. The subagent:

- Starts from the skill's `template.html`.
- Produces one self-contained HTML file.
- Inlines CSS, JavaScript, screenshots, and other required assets.
- Uses the required annotation and feedback layer.
- Places the visual overview before detailed prose.
- Uses stable `data-note` section identifiers and linked deep dives.
- Creates screenshots, diagrams, comparison cards, timelines, or code examples
  only when they explain a genuine relationship.
- Preserves source attribution near each supported claim.

Official screenshots may be captured or embedded when they directly show the
new capability. When no honest screenshot exists, the report uses an
explanatory workflow diagram or example rather than fabricating an interface.

The HTML subagent is a presentation specialist. It must not expand the selected
scope, invent discoveries, or replace evidence supplied by the orchestrator.

## Report information architecture

The report reads like a curated learning magazine:

1. **Title and purpose** — what period and stack the report covers.
2. **At a glance** — the three to seven strongest discoveries in one visual
   overview.
3. **New shiny things** — one linked deep dive per selected discovery.
4. **Smaller sparkles** — concise user-visible improvements that did not merit
   a full section.
5. **Worth discovering** — zero to two exceptional adjacent tools.
6. **Quiet maintenance** — collapsed counts without a bug-fix essay.
7. **Brief heads-up** — breaking changes only when needed to use or understand a
   featured capability.
8. **Coverage and sources** — inspected components, gaps, and authoritative
   links.

Each primary discovery answers:

- What can I do now?
- Why would I care?
- Where does this fit in my setup?
- How can I try or visualize it?
- Where can I learn more?

The report may contain fewer than three discoveries when the evidence does not
support more. If nothing genuinely interesting happened, the skill reports a
quiet cycle plainly instead of padding the document.

## Read-only boundary

The workflow may write only:

- Temporary collection and research artifacts.
- The final HTML report.
- Skill-owned coverage state.

It must not change:

- Neovim configuration files.
- `lazy-lock.json`.
- Installed plugin working trees or checked-out revisions.
- Mason package contents or receipts.
- Neovim data, cache, or state as part of an update operation.

Remote inspection must use non-checkout operations or disposable temporary
copies. The verification phase compares pre-run and post-run snapshots of the
protected targets.

## Error handling

Failures are isolated by component:

- Missing config or lockfile: stop with a clear diagnostic and do not update
  state.
- Missing plugin remote: retain prior coverage and list the component as
  uninspected.
- Network or API failure: retry only within a small bound, use another
  authoritative source when available, and otherwise leave the component
  pending.
- Rate limiting: prefer already-collected evidence or defer the affected
  component rather than lowering evidence standards.
- Missing changelog: inspect official commits, pull requests, and documentation;
  omit the item if its user benefit remains unclear.
- Ambiguous version compatibility or divergent history: do not infer a target;
  retain the prior baseline.
- Missing screenshot: use a diagram or example, or omit the visual.
- HTML-generation failure: preserve the evidence bundle for retry and do not
  advance coverage.
- Partial success: publish only when the report clearly identifies gaps, and
  advance only components that were fully processed.

## State integrity

`state.json` is versioned with a schema number and records:

- Configuration identity.
- Generation time and report path.
- Per-plugin covered revision and installed revision observed at report time.
- Per-Mason-package covered version and installed version observed at report
  time.
- Adjacent discoveries already featured.
- Components deferred because of collection or evidence failures.

State is written atomically after verification. A failed run leaves the prior
file untouched. Corrupt or incompatible state is backed up and treated as
unavailable; it must never cause changes to Neovim.

## Verification strategy

### Collector tests

Use fixtures and temporary repositories to cover:

- `NVIM_APPNAME` resolution, default fallback, and explicit path override.
- First run without history.
- A normal lock-to-upstream change.
- An update performed before the next report.
- A target already covered but not yet installed.
- Compatible tag and pinned-version selection.
- Divergent or force-pushed history.
- Missing and non-GitHub remotes.
- Mason receipts with and without available updates.
- Partial network/source failure.
- Atomic state writes and corrupt state recovery.

Use local bare Git repositories for deterministic integration tests instead of
depending on live upstream state.

### Editorial forward tests

Forward-test the completed skill with fresh subagents and realistic fixture
manifests. Tests must demonstrate that it:

- Selects capabilities rather than copying update text.
- Suppresses fix-heavy maintenance.
- Explains why a feature matters and what it enables.
- Respects the three-to-seven cap without padding.
- Omits unsupported claims.
- Does not repeat already-covered stories.
- Keeps adjacent discoveries rare and relevant.

### HTML verification

Apply the complete `zimakki-html-doc` checklist:

- Opens standalone without console errors.
- Contains no required external assets or runtime network requests.
- Shows a visual overview before the detail.
- Preserves meaning and reading order at narrow widths.
- Displays comment affordances and the feedback control.
- Uses stable anchors and working internal links.
- Embeds and attributes screenshots correctly.

### Read-only verification

Snapshot before and after:

- Configuration repository status and relevant file checksums.
- `lazy-lock.json` checksum.
- Installed plugin `HEAD` revisions and working-tree status.
- Mason receipt checksums.

Any unexpected change fails the run, prevents state advancement, and is
reported explicitly.

## Acceptance criteria

- `/zimakki-nvim-update-brief` can run outside Neovim against the active or an
  explicitly selected configuration.
- It produces a self-contained HTML learning brief assembled by a
  `zimakki-html-doc` subagent.
- The report contains at most seven primary discoveries and may contain fewer.
- Every highlighted claim has relevant authoritative evidence.
- Each highlight explains what changed, why it matters, and what workflow it
  enables.
- Routine fix detail is absent from the main narrative.
- Re-running without new upstream changes does not repeat prior discoveries.
- Updating Neovim before running the next report does not lose already-tracked
  coverage.
- Config, lockfile, plugin revisions, and Mason packages are unchanged after a
  run.
- Coverage state advances only after successful verification and only for
  components actually covered.

## Settled decisions

- Skill name: `zimakki-nvim-update-brief`.
- External, report-only workflow.
- Hybrid deterministic collector plus agent research.
- Installed stack first; exceptional adjacent discoveries only.
- Three to seven primary discoveries, with no padding.
- Learning and workflow enablement over fixes and upgrade risk.
- Persistent per-component coverage memory outside Neovim.
- Dedicated `zimakki-html-doc` subagent for final presentation.
- Self-contained HTML output with screenshots or diagrams when useful.

There are no unresolved product decisions in this design.
