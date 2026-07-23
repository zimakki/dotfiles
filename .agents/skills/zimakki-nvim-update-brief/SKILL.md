---
name: zimakki-nvim-update-brief
description: Use when the user wants to learn what is new, interesting, or newly possible in their AstroNvim, Lazy plugin, or Mason tool stack without applying updates, especially for a visual what's-new report focused on workflows rather than fixes.
---

# Neovim update brief

Create a read-only learning brief about the few changes that enable genuinely
useful capabilities.

## Non-negotiable boundary

Never invoke Neovim, Lazy, Mason, installers, or mutating Git commands. Never
edit config, lockfiles, plugin trees, Mason packages, or receipts.

Target active v6: respect an explicit path, otherwise use `NVIM_APPNAME`. If it
resolves to v4, stop. Never inspect or fall back to v4.

## Workflow

### 1. Collect the facts

Resolve this skill's directory as `skill_dir`, then run:

```sh
elixir "$skill_dir/scripts/update_brief.exs" collect
```

Pass `--config PATH` only for a user-supplied v6 config. Read the printed
manifest and confirm `runtime.config_dir` is correct. Treat warnings as pending.

### 2. Research what became possible

Read [references/editorial-policy.md](references/editorial-policy.md) completely.
Research candidate Lazy ranges, then Mason tools with a clear upstream target.
Use primary official sources. Explain what the user can do, why it matters, and
the enabled workflow; never copy release-note prose. Label activation
`automatic`, `available after update`, `opt-in`, or `integration-dependent`.
Keep unclear evidence or ancestry pending.

### 3. Curate and record decisions

Select zero to seven discoveries without padding. Allow at most two uninstalled
tools with authoritative evidence of unusually direct local fit.

Write `evidence.md` and `coverage.json` beside the manifest using the reference
contracts. Mark a handled range `featured` or `no_learning_value`; omit partial
research so it remains pending.

### 4. Delegate presentation

Spawn a dedicated presentation subagent and require it to use
`zimakki-html-doc` (provide its path when needed). Pass only `evidence.md`, a
report path under `reports/`, and this contract:

- one self-contained HTML brief with visual overview before linked deep dives;
- nearby sources and supplied official screenshots or honest diagrams;
- the required annotation/feedback layer;
- no added discoveries, claims, config advice, or scope.

Require the report path. Without a distinct subagent or `zimakki-html-doc`,
preserve run files and do not advance coverage.

### 5. Verify and complete

Apply the `zimakki-html-doc` verification checklist. Confirm the overview,
links, stable IDs, inlined assets, nearby sources, and seven-item cap.

Then run:

```sh
elixir "$skill_dir/scripts/update_brief.exs" complete \
  --run "$manifest_path" \
  --coverage "$coverage_path" \
  --report "$report_path"
```

`complete` rechecks known Neovim artifacts before atomically advancing only
processed coverage. On failure, report the diagnostic; prior state stays intact.

Return a clickable report path and pending components. Nothing in Neovim was
updated.
