# zimakki-nvim-update-brief: lean Elixir implementation design

Date: 2026-07-21  
Status: Approved

## Relationship to the product design

This is an implementation delta for the approved
[`zimakki-nvim-update-brief` product design](./2026-07-21-zimakki-nvim-update-brief-design.md).
It does not change the product: the skill remains an external, report-only
learning tool that finds a small number of genuinely useful new Neovim
capabilities and delegates the final visual brief to a dedicated
`zimakki-html-doc` subagent.

This delta replaces the Python implementation plan as the active direction.
The existing Python feature branch and worktree remain untouched as reference.

## Why this version is deliberately smaller

The first implementation treated local metadata and paths as hostile input and
grew protections for path aliasing, hard links, filesystem races, concurrent
writers, malformed identity data, and other adversarial cases. That boundary
does not match this personal tool.

The Elixir version assumes:

- it runs as the user on their own machine;
- the configured Neovim, Lazy, Mason, and brief directories are trusted;
- only one brief runs at a time;
- local Git and JSON metadata are ordinary well-formed tool output;
- failures may stop the run with a useful message instead of being recovered
  through a general transaction framework.

It still makes no Neovim changes. Read-only is a product invariant, not a
hostile-filesystem security claim.

## Chosen approach

Use one dependency-free Elixir script for deterministic local bookkeeping and
keep interpretation in the skill workflow.

The script has two operations:

1. `collect` reads the active `lazy-lock.json`, installed Lazy repositories,
   Mason receipts, and prior brief state. It uses read-only Git commands such as
   `git rev-parse`, `git status`, and `git ls-remote`, then writes a candidate
   manifest under the brief's own data directory.
2. `complete` receives the generated report and a small coverage file, checks
   that the known lockfile, plugin heads/statuses, and Mason receipts still
   match the collection snapshot, then atomically replaces the skill-owned
   `state.json`.

The Codex skill orchestrator performs primary-source research, decides what is
actually interesting, and asks a dedicated subagent to use
`zimakki-html-doc`. The script does not scrape or summarize changelogs and does
not try to make editorial decisions.

This split keeps deterministic facts in code and the valuable learning work in
the agent workflow.

## Alternatives considered

### Keep and finish the hardened Python implementation

This preserves the completed safety machinery, but keeps thousands of lines
whose complexity is unrelated to the trusted personal workflow. Rejected as
the default; preserved on its feature branch for reference.

### Rebuild the same architecture in Elixir

This changes the language without fixing the scope error. It would reproduce
the same path, locking, recovery, and concurrency subsystems. Rejected.

### Use no deterministic script

An entirely prompt-driven skill would be shortest initially, but per-component
memory and repeatable read-only checks would become fragile. Rejected in favor
of one small Elixir boundary.

## Files and boundaries

The implementation should remain easy to read in one sitting:

```text
.agents/skills/zimakki-nvim-update-brief/
├── SKILL.md
├── agents/openai.yaml
├── references/editorial-policy.md
└── scripts/update_brief.exs

tests/skills/zimakki_nvim_update_brief_test.exs
```

If the script becomes difficult to understand as one file, it may be split
into a small number of focused Elixir files. It must not become a generic
filesystem-safety, HTTP, concurrency, or persistence library.

No Mix project and no third-party dependency are required. The repository's
pinned Elixir/OTP provides JSON support; Git provides read-only remote
inspection.

## Data flow

```text
trusted local metadata + previous state
                  |
                  v
       Elixir `collect` manifest
                  |
                  v
      agent research and curation
                  |
                  v
  `zimakki-html-doc` presentation subagent
                  |
                  v
        verified HTML + coverage file
                  |
                  v
      Elixir `complete` state advance
```

Per-component state records the last revision or version deliberately
processed. A processed component may have produced a featured story or have
been classified as having no learning value. Uninspected and ambiguous
components remain at their old baseline.

This means:

- an update performed after an established baseline is still visible;
- an already-reported upstream feature is not repeated merely because it has
  not been installed yet;
- the unavoidable first run starts at the current observed state unless a
  simple prior lock revision is readily available;
- uncertain history is left pending rather than reconstructed through complex
  heuristics.

## Editorial workflow

The final report remains the purpose of the tool. It should normally contain
three to seven strong discoveries, never more than seven and never padded.
Each featured item explains:

- what is newly possible;
- why that is useful or interesting for this setup;
- the workflow it enables;
- whether it is automatic, update-dependent, or opt-in;
- the smallest useful way to try or understand it;
- the primary sources supporting it.

Routine fixes, maintenance, dependency bumps, and copied release-note prose are
collapsed or omitted. At most two unusually relevant adjacent tools may be
included.

## Read-only guarantee

The workflow may write only temporary research files, the report, and files
under `~/.local/share/zimakki-nvim-update-brief/` (or an explicit test brief
home).

It never invokes Neovim, Lazy, Mason, package installers, Git checkout/reset/
pull, or any update command. Before advancing coverage it rechecks the known
lockfile, installed plugin heads and statuses, and Mason receipt hashes captured
at collection time. A difference stops completion and leaves prior state
untouched.

This guard detects accidental mutation by the workflow. It intentionally does
not defend against malicious local paths, hard-link tricks, races, or multiple
simultaneous runs.

## Error handling

- Missing configuration or `lazy-lock.json`: stop with a direct diagnostic.
- Unavailable plugin remote or upstream target: keep that component pending.
- Network or source failure: research what can be supported and retain the old
  baseline for the rest.
- Missing Mason source/version detail: keep the installed facts and let the
  research step decide whether it can proceed.
- HTML or read-only verification failure: do not update coverage state.
- No worthwhile discoveries: produce an honest quiet-cycle brief rather than
  inventing content.

## Testing and size guard

Use ExUnit fixtures with temporary config, Lazy repositories, Mason receipts,
brief state, and local bare Git remotes. Cover the useful contract:

- configuration resolution;
- Lazy and Mason discovery;
- prior baseline versus current/remote target;
- a user updating before the next report;
- no repetition after a target is processed;
- partial/unavailable components staying pending;
- successful state advancement;
- refusal to advance after a known Neovim artifact changes.

Also forward-test the completed skill once against a representative manifest to
confirm its editorial and `zimakki-html-doc` instructions. Do not add tests for
hostile path aliases, hard links, race injection, simultaneous writers, or
generic schema fuzzing.

The implementation target is hundreds of lines, not thousands. Crossing 1,000
non-generated lines for the script and its tests requires an explicit design
revisit rather than incremental justification.

## Acceptance criteria

- The canonical skill is named `zimakki-nvim-update-brief` and runs outside
  Neovim.
- Its deterministic implementation is Elixir using only OTP and Git.
- It never updates or invokes Neovim, Lazy, or Mason.
- It remembers processed ranges per component outside Neovim.
- It preserves pending components when evidence is unavailable.
- It explains a maximum of seven new capabilities in learning-oriented prose,
  suppressing fix-heavy detail.
- A dedicated subagent must use `zimakki-html-doc` for the self-contained final
  report.
- Coverage advances only after the report exists and known Neovim artifacts
  still match the collection snapshot.
- The old Python branch remains available and unchanged as reference.

There are no unresolved implementation decisions in this delta.
