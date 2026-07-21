# Lean Elixir Neovim Update Brief Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved `zimakki-nvim-update-brief` skill with one small dependency-free Elixir helper, per-component memory, read-only verification, and a dedicated `zimakki-html-doc` presentation subagent.

**Architecture:** A single Elixir script owns trusted local discovery, candidate bookkeeping, a before/after guard, and atomic coverage-state replacement. The skill owns primary-source research and learning-oriented curation; a separate subagent owns final HTML presentation. The abandoned hardened Python branch remains untouched.

**Tech Stack:** Elixir 1.20.2, OTP 29 `:json`, Git read-only commands, ExUnit, Agent Skills Markdown/YAML, Codex subagents, `zimakki-html-doc`.

## Global Constraints

- Canonical source is `.agents/skills/zimakki-nvim-update-brief/`.
- Use no Mix project, Hex package, Python implementation, or new system dependency.
- Keep `scripts/update_brief.exs` plus its test below 1,000 non-generated lines.
- Assume trusted local paths, well-formed tool metadata, and one run at a time.
- Do not implement hard-link defenses, path-alias defenses, race injection, writer locks, schema fuzzing, or generic recovery infrastructure.
- Never invoke Neovim, Lazy, Mason, package installers, or mutating Git commands.
- Write only the final report, temporary research artifacts, and files under the skill-owned brief home.
- Highlight at most seven discoveries; never pad; suppress routine fixes and copied changelog prose.
- Use primary sources and no more than two exceptional adjacent discoveries.
- Final HTML assembly always goes to a dedicated subagent explicitly required to use `zimakki-html-doc`.
- Advance only deliberately processed components and only after report/read-only verification succeeds.

---

## File map

- `.agents/skills/zimakki-nvim-update-brief/scripts/update_brief.exs` — local inventory, candidate/state calculation, CLI, and read-only completion guard.
- `tests/skills/zimakki_nvim_update_brief_test.exs` — focused ExUnit contract tests using temporary fixtures and injected Git results.
- `.agents/skills/zimakki-nvim-update-brief/SKILL.md` — end-to-end research, curation, HTML delegation, and completion workflow.
- `.agents/skills/zimakki-nvim-update-brief/references/editorial-policy.md` — compact scoring, evidence, and coverage rules.
- `.agents/skills/zimakki-nvim-update-brief/agents/openai.yaml` — Codex display metadata.

### Task 1: Collect trusted Lazy and Mason facts

**Files:**

- Create: `tests/skills/zimakki_nvim_update_brief_test.exs`
- Create: `.agents/skills/zimakki-nvim-update-brief/scripts/update_brief.exs`

**Interfaces:**

- `Zimakki.NvimUpdateBrief.resolve_paths(opts, env) :: map()`
- `Zimakki.NvimUpdateBrief.build_manifest(opts, env, run_git) :: map()`
- `run_git.(args, cwd) :: {:ok, output} | {:error, reason}` where `cwd` may be
  `nil` for `git ls-remote`.
- CLI: `elixir update_brief.exs collect [--config PATH] [--brief-home PATH]`

- [ ] **Step 1: Write failing discovery tests**

Create a temporary fixture with `astronvim_v6/lazy-lock.json`, one installed
Git plugin, and one Mason receipt. Set `ZIMAKKI_UPDATE_BRIEF_NO_MAIN=1` before
requiring the script. Assert the stable public contract:

```elixir
assert paths.app_name == "astronvim_v6"
assert paths.config_dir == Path.expand(config)
assert paths.data_dir == Path.join(data_home, "astronvim_v6")

assert %{
  "component_id" => "lazy:folke/snacks.nvim",
  "baseline" => locked,
  "target" => remote,
  "candidate" => true
} = hd(manifest["lazy"])

assert %{
  "component_id" => "mason:stylua",
  "installed_version" => "v2.5.0"
} = hd(manifest["mason"])
```

Use an injected `run_git` function that answers only `remote get-url origin`,
`rev-parse HEAD`, `status --porcelain`, and `ls-remote`. Add focused tests for
explicit config precedence, `NVIM_APPNAME` fallback, missing lockfile, an
unavailable remote remaining unresolved, and an already-covered remote target
not becoming a candidate again.

- [ ] **Step 2: Run the discovery tests and confirm red**

Run:

```bash
elixir tests/skills/zimakki_nvim_update_brief_test.exs
```

Expected: failure because `scripts/update_brief.exs` does not exist.

- [ ] **Step 3: Implement the minimal collector**

Define `Zimakki.NvimUpdateBrief` in the script with these fixed responsibilities:

```elixir
@schema 1

def resolve_paths(opts, env) do
  home = Map.fetch!(env, "HOME")
  app_name = Map.get(env, "NVIM_APPNAME", "nvim")
  config_home = Map.get(env, "XDG_CONFIG_HOME", Path.join(home, ".config"))
  data_home = Map.get(env, "XDG_DATA_HOME", Path.join(home, ".local/share"))
  config_dir = opts[:config] || Path.join(config_home, app_name)

  %{
    app_name: app_name,
    config_dir: Path.expand(config_dir),
    data_dir: Path.expand(Path.join(data_home, app_name)),
    brief_home: Path.expand(opts[:brief_home] || Path.join(data_home, "zimakki-nvim-update-brief"))
  }
end
```

Use `:json.decode/1` for `lazy-lock.json` and Mason `receipt.json` files. For
each Lazy entry, collect its origin, installed head/status, GitHub repository
identity when recognizable, and a best-effort upstream branch head through
`git ls-remote`. For each Mason package, retain its installed version and
source identifier without trying to solve every package ecosystem.

Load `state.json` when present. A Lazy candidate is new when the best known
target differs from its covered baseline. First-run baseline is the current
locked revision. A Mason entry is always available to research, but is marked
candidate only when the installed version differs from prior coverage.
Unavailable Git facts become `null` plus a component warning; they do not stop
other components.

The manifest must include `schema`, `generated_at`, serializable `runtime`,
`lazy`, `mason`, prior adjacent discoveries, and a local guard containing the
lockfile hash, plugin head/status, and receipt hashes.

Set `runtime.config_id` to the lowercase SHA-256 digest of the expanded
configuration path so the same trusted configuration keeps one state namespace.

The `collect` CLI writes a timestamped JSON file under
`<brief_home>/runs/`, prints that path, and exits nonzero with a direct message
for missing config/lockfile or malformed top-level JSON.

- [ ] **Step 4: Run tests and confirm green**

Run:

```bash
elixir tests/skills/zimakki_nvim_update_brief_test.exs
```

Expected: all discovery tests pass with zero failures.

- [ ] **Step 5: Commit the collector**

```bash
git add .agents/skills/zimakki-nvim-update-brief/scripts/update_brief.exs \
  tests/skills/zimakki_nvim_update_brief_test.exs
git commit -m "feat: collect Neovim update brief facts in Elixir"
```

### Task 2: Complete a report and advance only covered state

**Files:**

- Modify: `.agents/skills/zimakki-nvim-update-brief/scripts/update_brief.exs`
- Modify: `tests/skills/zimakki_nvim_update_brief_test.exs`

**Interfaces:**

- `Zimakki.NvimUpdateBrief.complete(run_path, coverage_path, report_path, env, run_git) :: :ok | {:error, String.t()}`
- CLI: `elixir update_brief.exs complete --run PATH --coverage PATH --report PATH`
- Coverage JSON:

```json
{
  "processed": [
    {"component_id": "lazy:folke/snacks.nvim", "through": "abc123", "disposition": "featured"},
    {"component_id": "mason:stylua", "through": "v2.5.0", "disposition": "no_learning_value"}
  ],
  "adjacent": ["github:someone/useful.nvim"]
}
```

- [ ] **Step 1: Write failing completion tests**

Add tests proving:

```elixir
assert :ok = Brief.complete(run_path, coverage_path, report_path, env, run_git)
state = Path.join(brief_home, "state.json") |> File.read!() |> :json.decode()
config_id = manifest["runtime"]["config_id"]
plugin_id = "lazy:folke/snacks.nvim"
pending_id = "mason:stylua"
assert state["configs"][config_id]["components"][plugin_id]["covered"] == remote
assert state["configs"][config_id]["components"][pending_id]["covered"] == old
```

Also assert that a changed lockfile, plugin head/status, or Mason receipt returns
`{:error, message}`, leaves the previous state byte-for-byte unchanged, and
that a missing HTML report is rejected.

- [ ] **Step 2: Run the focused tests and confirm red**

Run:

```bash
elixir tests/skills/zimakki_nvim_update_brief_test.exs
```

Expected: completion assertions fail because `complete/5` is undefined.

- [ ] **Step 3: Implement completion without a transaction framework**

Read the manifest and coverage JSON, confirm the report is a regular file with
an HTML document marker, and rebuild only the local guard from the runtime and
component paths already recorded in the manifest. Compare guards for exact
equality.

Validate each `processed` entry against a manifest component ID and require
`disposition` to be `featured` or `no_learning_value`. Merge only those entries
into the matching configuration's component state; preserve every other
baseline. Deduplicate the coverage file's adjacent IDs with previous adjacent
IDs.

Write the new versioned state to `<brief_home>/state.json.tmp`, then rename it
over `state.json`. Remove the temporary file on an ordinary write/rename error.
Do not add locking, retries, corrupt-state repair, symlink analysis, or race
handling.

Add `complete` CLI parsing with required `--run`, `--coverage`, and `--report`
options. On a guard or validation error, print the diagnostic to stderr and
exit nonzero without changing state.

- [ ] **Step 4: Run tests and enforce the size boundary**

Run:

```bash
elixir tests/skills/zimakki_nvim_update_brief_test.exs
wc -l .agents/skills/zimakki-nvim-update-brief/scripts/update_brief.exs \
  tests/skills/zimakki_nvim_update_brief_test.exs
```

Expected: zero test failures and combined total below 1,000 lines.

- [ ] **Step 5: Commit completion**

```bash
git add .agents/skills/zimakki-nvim-update-brief/scripts/update_brief.exs \
  tests/skills/zimakki_nvim_update_brief_test.exs
git commit -m "feat: finalize Neovim learning brief state"
```

### Task 3: Author and forward-test the skill workflow

**Files:**

- Create: `.agents/skills/zimakki-nvim-update-brief/SKILL.md`
- Create: `.agents/skills/zimakki-nvim-update-brief/references/editorial-policy.md`
- Create: `.agents/skills/zimakki-nvim-update-brief/agents/openai.yaml`

**Interfaces:**

- Invocation: `$zimakki-nvim-update-brief` or `/zimakki-nvim-update-brief`
- Consumes: the `collect` manifest and primary-source research.
- Produces: one self-contained HTML report plus coverage JSON consumed by
  `complete`.

- [ ] **Step 1: Write the workflow contract**

Create `SKILL.md` with valid matching frontmatter and these mandatory stages:

1. Run `collect`; never run Neovim, Lazy, Mason, or a mutating Git command.
2. Snapshot/check the configured v6 target shown in the manifest.
3. Research candidate ranges from primary official sources. Explain capability,
   benefit, enabled workflow, opt-in/update status, smallest useful try-it, and
   supporting source. Do not reproduce release notes.
4. Rank with `references/editorial-policy.md`; select at most seven without
   padding, plus at most two exceptional adjacent tools.
5. Write a bounded evidence bundle and coverage JSON under the run directory.
6. Spawn a **dedicated** presentation subagent whose prompt says it **must use
   `zimakki-html-doc`**, must not add discoveries, and must return the report
   path.
7. Inspect the HTML against the house checklist, then run `complete`.
8. If any stage fails, retain the manifest/evidence for diagnosis and do not
   advance state.

The editorial reference must define an explicit keep/drop rubric. New visible
workflows, useful opt-ins, and configuration-relevant capabilities rank high;
routine fixes, maintenance, dependencies, internal refactors, and vague claims
drop. Breaking changes appear only when necessary to understand a featured
capability.

- [ ] **Step 2: Generate metadata and validate canonical structure**

Generate `agents/openai.yaml` with:

```yaml
interface:
  display_name: "Neovim What's New"
  short_description: "Learn what new Neovim updates enable"
  default_prompt: "Use $zimakki-nvim-update-brief to create a read-only visual learning brief about newly possible workflows in my Neovim stack."
```

Run:

```bash
python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py \
  .agents/skills/zimakki-nvim-update-brief
scripts/ci_checks.sh
```

Expected: skill validation and repository checks pass. From a worktree, do not
repair live discovery links.

- [ ] **Step 3: Forward-test the skill with a fresh subagent**

Give a fresh subagent a representative fixture manifest containing one
workflow-enabling feature, one opt-in improvement, several routine fixes, one
unsupported claim, and eight otherwise valid highlights. Ask it to follow the
new skill through evidence-bundle selection without changing files.

Expected output:

- no more than seven highlights;
- the workflow and opt-in benefits are explained rather than copied;
- routine fixes and the unsupported claim are excluded;
- coverage includes processed and no-learning-value dispositions;
- the final presentation instruction requires a distinct
  `zimakki-html-doc` subagent.

- [ ] **Step 4: Perform one real read-only collection against v6**

Run `collect` against the current v6 configuration with a temporary explicit
brief home. Record checksums/status before and after and compare them. Do not
run `complete`, because this implementation verification is not a genuine
published learning cycle.

Expected: a valid manifest, no Neovim changes, and useful component warnings
rather than a whole-run failure for unavailable remotes.

- [ ] **Step 5: Commit and verify the complete branch**

```bash
git add .agents/skills/zimakki-nvim-update-brief
git commit -m "feat: add Neovim what's-new learning skill"
elixir tests/skills/zimakki_nvim_update_brief_test.exs
scripts/ci_checks.sh
git diff --check master...HEAD
```

Expected: all checks pass, the old Python worktree remains unchanged, and the
Elixir script plus tests remain below 1,000 lines.
