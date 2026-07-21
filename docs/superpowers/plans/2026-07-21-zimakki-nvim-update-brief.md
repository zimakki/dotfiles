# zimakki-nvim-update-brief Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal, external, read-only Codex skill that discovers newly available capabilities in the active Neovim stack and produces a curated self-contained HTML learning brief through a dedicated `zimakki-html-doc` subagent.

**Architecture:** A Python standard-library collector establishes the active AstroNvim configuration, installed Lazy/Mason revisions, compatible upstream targets, and per-component coverage baseline without checking out or installing anything. The skill orchestrates primary-source research and curation, delegates presentation to `zimakki-html-doc`, verifies protected Neovim state, then atomically advances only coverage represented by the verified report.

**Tech Stack:** Python 3.13 standard library, Git CLI read-only queries, GitHub/raw HTTP and npm registry JSON, Agent Skills Markdown/YAML, Codex subagents, `zimakki-html-doc`.

## Global Constraints

- Use `superpowers:test-driven-development` for Tasks 1–5 and
  `superpowers:verification-before-completion` before any completion claim.
- Canonical source: `.agents/skills/zimakki-nvim-update-brief/`.
- Add no Python, Homebrew, npm, or Neovim runtime dependency.
- Resolve explicit `--config`, otherwise `NVIM_APPNAME`, otherwise `~/.config/nvim`.
- Store reports/state under `~/.local/share/zimakki-nvim-update-brief/`; allow `--brief-home` for isolated tests.
- Never run Lazy sync/update/install, Mason update/install, or source the active Neovim config.
- Never change config, `lazy-lock.json`, plugin `HEAD`/working trees, Mason contents, or Mason receipts.
- Use static config/lock metadata, AstroNvim's checked-in `lazy_snapshot.lua`, `git ls-remote`, and HTTP GET only.
- Highlight at most seven discoveries, normally three to seven, without padding.
- Explain what changes enable; suppress routine fixes and copied changelog prose.
- Use primary official sources and at most two exceptional adjacent discoveries.
- Mention breaking changes only when needed to understand or try a highlight.
- Always delegate final HTML assembly to a dedicated `zimakki-html-doc` subagent.
- Advance component coverage only after HTML and read-only verification succeed.

---

## File map

- `.agents/skills/zimakki-nvim-update-brief/SKILL.md` — orchestration.
- `.agents/skills/zimakki-nvim-update-brief/agents/openai.yaml` — UI metadata.
- `.agents/skills/zimakki-nvim-update-brief/references/contracts.md` — JSON contracts.
- `.agents/skills/zimakki-nvim-update-brief/references/editorial-policy.md` — selection rules.
- `.agents/skills/zimakki-nvim-update-brief/scripts/collect_updates.py` — collector CLI.
- `.agents/skills/zimakki-nvim-update-brief/scripts/read_only_guard.py` — guard CLI.
- `.agents/skills/zimakki-nvim-update-brief/scripts/finalize_report.py` — finalizer CLI.
- `.agents/skills/zimakki-nvim-update-brief/scripts/update_brief/models.py` — records.
- `.agents/skills/zimakki-nvim-update-brief/scripts/update_brief/discovery.py` — local inventory.
- `.agents/skills/zimakki-nvim-update-brief/scripts/update_brief/versions.py` — version rules.
- `.agents/skills/zimakki-nvim-update-brief/scripts/update_brief/remotes.py` — targets.
- `.agents/skills/zimakki-nvim-update-brief/scripts/update_brief/state.py` — coverage.
- `.agents/skills/zimakki-nvim-update-brief/scripts/update_brief/guard.py` — snapshots.
- `.agents/skills/zimakki-nvim-update-brief/scripts/update_brief/html_report.py` — HTML checks.
- `tests/skills/test_nvim_update_brief_*.py` — deterministic tests.

---

### Task 1: Scaffold the skill and discover local state

**Files:**

- Create: `.agents/skills/zimakki-nvim-update-brief/{SKILL.md,agents/openai.yaml}`
- Create: `.agents/skills/zimakki-nvim-update-brief/scripts/collect_updates.py`
- Create: `.agents/skills/zimakki-nvim-update-brief/scripts/update_brief/{__init__.py,models.py,discovery.py}`
- Create: `tests/skills/test_nvim_update_brief_discovery.py`

**Interfaces:**

- `resolve_runtime(config_arg, environ, brief_home_arg) -> RuntimePaths`
- `discover_lazy(paths) -> list[LazyPlugin]`
- `discover_mason(paths) -> list[MasonPackage]`
- `build_local_manifest(paths) -> dict[str, object]`
- `collect_updates.py --output PATH [--config PATH] [--brief-home PATH]`

- [ ] **Step 1: Initialize the canonical skill**

```bash
python3 /Users/zimakki/.codex/skills/.system/skill-creator/scripts/init_skill.py \
  zimakki-nvim-update-brief \
  --path .agents/skills \
  --resources scripts,references \
  --interface 'display_name=Neovim Update Brief' \
  --interface 'short_description=Learn what new Neovim updates enable' \
  --interface 'default_prompt=Use $zimakki-nvim-update-brief to create a read-only visual learning brief about new capabilities in my Neovim stack.'
```

Replace generated starter prose immediately with a valid interim `SKILL.md`:

```markdown
---
name: zimakki-nvim-update-brief
description: Create a read-only learning brief about newly available capabilities in an AstroNvim, Lazy, and Mason setup. Use when the user asks what is new, changed, interesting, or newly possible in their Neovim stack without applying updates.
---

# Neovim update brief

Inspect the active Neovim configuration without updating it. Run
`scripts/collect_updates.py` to build the local inventory. Never run Lazy
sync/update/install or Mason update/install.
```

- [ ] **Step 2: Write the failing discovery fixture**

Create `tests/skills/test_nvim_update_brief_discovery.py`. In `setUp`, create a
temporary HOME with:

```python
self.config = self.home / "code/astronvim_v6"
self.entry = self.home / ".config/astronvim_v6"
self.entry.symlink_to(self.config, target_is_directory=True)
self.data = self.home / ".local/share/astronvim_v6"
self.env = {"HOME": str(self.home), "NVIM_APPNAME": "astronvim_v6"}
```

Create a real temporary Git plugin at
`self.data / "lazy/snacks.nvim"`, commit `README.md`, add origin
`git@github.com:folke/snacks.nvim.git`, and write its commit to:

```python
{
    "snacks.nvim": {"branch": "main", "commit": self.plugin_head}
}
```

in `lazy-lock.json`. Add this Mason receipt:

```python
{
    "schema_version": "2.0",
    "name": "stylua",
    "source": {"id": "pkg:github/johnnymorganz/stylua@v2.5.2"}
}
```

Tests must assert:

```python
paths = resolve_runtime(None, self.env)
self.assertEqual(paths.app_name, "astronvim_v6")
self.assertEqual(paths.config_entry, self.entry)
self.assertEqual(paths.config_dir, self.config.resolve())
self.assertEqual(paths.data_dir, self.data)

plugin = discover_lazy(paths)[0]
self.assertEqual(plugin.repository, "folke/snacks.nvim")
self.assertEqual(plugin.locked_commit, self.plugin_head)
self.assertEqual(plugin.installed_head, self.plugin_head)

package = discover_mason(paths)[0]
self.assertEqual(
    (package.name, package.ecosystem, package.package, package.installed_version),
    ("stylua", "github", "johnnymorganz/stylua", "v2.5.2"),
)

manifest = build_local_manifest(paths)
json.dumps(manifest, sort_keys=True)
self.assertEqual(manifest["lazy"][0]["component_id"], "lazy:folke/snacks.nvim")
self.assertEqual(manifest["mason"][0]["component_id"], "mason:stylua")
```

Add separate resolution tests proving that an explicit `--config` path wins
over a conflicting `NVIM_APPNAME`, that an environment without
`NVIM_APPNAME` falls back to `~/.config/nvim`, and that an explicit
`--brief-home` is preserved in `RuntimePaths`.

Also assert `DiscoveryError` for a missing lockfile, malformed lock JSON, an
invalid Mason receipt, and an unsupported Mason PURL. These are four separate
test methods so each diagnostic remains identifiable. A missing install
directory or non-GitHub origin must instead retain the Lazy entry with an
unresolved repository and a component-specific warning; it must not abort the
rest of the inventory.

- [ ] **Step 3: Verify the discovery test fails**

Run: `python3 -m unittest tests.skills.test_nvim_update_brief_discovery -v`

Expected: FAIL with `ModuleNotFoundError: No module named 'update_brief'`.

- [ ] **Step 4: Implement typed records**

Create `scripts/update_brief/__init__.py`:

```python
"""Deterministic support for zimakki-nvim-update-brief."""
SCHEMA_VERSION = 1
```

Create `models.py`:

```python
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

@dataclass(frozen=True)
class RuntimePaths:
    app_name: str
    config_entry: Path
    config_dir: Path
    data_dir: Path
    cache_dir: Path
    nvim_state_dir: Path
    brief_home: Path
    def json(self) -> dict[str, str]:
        return {key: str(value) for key, value in asdict(self).items()}

@dataclass(frozen=True)
class LazyPlugin:
    name: str
    locked_commit: str
    branch: str
    install_dir: Path
    installed_head: str | None
    remote_url: str | None
    repository: str | None
    warning: str | None = None
    @property
    def component_id(self) -> str:
        return f"lazy:{self.repository or self.name}"
    def json(self) -> dict[str, Any]:
        value = asdict(self)
        value["install_dir"] = str(self.install_dir)
        value["component_id"] = self.component_id
        return value

@dataclass(frozen=True)
class MasonPackage:
    name: str
    source_id: str
    ecosystem: str
    package: str
    installed_version: str
    receipt_path: Path
    @property
    def component_id(self) -> str:
        return f"mason:{self.name}"
    def json(self) -> dict[str, str]:
        value = asdict(self)
        value["receipt_path"] = str(self.receipt_path)
        value["component_id"] = self.component_id
        return value
```

- [ ] **Step 5: Implement local discovery and CLI**

In `discovery.py`, implement:

```python
def resolve_runtime(config_arg, environ=os.environ, brief_home_arg=None):
    home = Path(environ.get("HOME", str(Path.home()))).expanduser()
    config_base = Path(environ.get("XDG_CONFIG_HOME", home / ".config"))
    if config_arg:
        entry = Path(config_arg).expanduser().absolute()
        app_name = entry.name
    else:
        app_name = environ.get("NVIM_APPNAME") or "nvim"
        entry = config_base / app_name
    if not entry.exists() or not (entry.resolve() / "lazy-lock.json").is_file():
        raise DiscoveryError(f"Neovim config or Lazy lockfile is missing: {entry}")
    data_base = Path(environ.get("XDG_DATA_HOME", home / ".local/share"))
    cache_base = Path(environ.get("XDG_CACHE_HOME", home / ".cache"))
    state_base = Path(environ.get("XDG_STATE_HOME", home / ".local/state"))
    brief_home = (Path(brief_home_arg).expanduser().absolute()
                  if brief_home_arg else data_base / "zimakki-nvim-update-brief")
    return RuntimePaths(app_name, entry, entry.resolve(), data_base / app_name,
                        cache_base / app_name, state_base / app_name, brief_home)
```

Parse `lazy-lock.json`; for each entry run only:

```python
git -C INSTALL_DIR rev-parse HEAD
git -C INSTALL_DIR remote get-url origin
```

Normalize GitHub SSH/HTTPS URLs to `owner/repo`. Parse Mason source IDs with:

```python
match = re.fullmatch(r"pkg:(github|npm)/(.+)@([^@]+)", source_id)
ecosystem, package, version = match.group(1), unquote(match.group(2)), unquote(match.group(3))
```

`build_local_manifest` returns schema version, UTC generation time, runtime,
sorted Lazy/Mason arrays, and warnings. `collect_updates.py` parses the three
CLI options, writes indented sorted JSON, prints the output path, and exits 2 on
`DiscoveryError` or `OSError`.

- [ ] **Step 6: Verify and commit local discovery**

```bash
python3 -m unittest tests.skills.test_nvim_update_brief_discovery -v
python3 .agents/skills/zimakki-nvim-update-brief/scripts/collect_updates.py \
  --config /Users/zimakki/.config/astronvim_v6 \
  --brief-home /tmp/zimakki-nvim-update-brief-plan-smoke \
  --output /tmp/zimakki-nvim-update-brief-plan-smoke/local-manifest.json
python3 -m json.tool /tmp/zimakki-nvim-update-brief-plan-smoke/local-manifest.json >/dev/null
git add .agents/skills/zimakki-nvim-update-brief tests/skills/test_nvim_update_brief_discovery.py
git commit -m "feat: discover Neovim update inventory"
```

Expected: all tests PASS, valid JSON is produced, and the commit succeeds.

---

### Task 2: Resolve compatible Lazy and Mason targets

**Files:**

- Create: `scripts/update_brief/{versions.py,remotes.py}`
- Modify: `scripts/update_brief/discovery.py`
- Modify: `scripts/collect_updates.py`
- Create: `tests/skills/test_nvim_update_brief_targets.py`

**Interfaces:**

- `parse_astronvim_policy(config_dir) -> tuple[str | None, bool]`
- `parse_snapshot(text) -> dict[str, SnapshotRule]`
- `select_latest_tag(tags, constraint="*")`
- `select_latest_release_tag(tags)` for stable semver and ISO-date releases.
- `RemoteClient.head/tags/text/json`
- `resolve_targets(manifest, client)`

- [ ] **Step 1: Write failing target tests**

Use a `FakeRemote` implementing the four `RemoteClient` methods. Assert:

```python
tags = {"v6.2.0": "a", "v6.4.1": "b", "v7.0.0": "c", "v6.5.0-beta.1": "d"}
self.assertEqual(select_latest_tag(tags, "^6"), ("v6.4.1", "b"))
self.assertEqual(select_latest_tag({"v0.4.1": "a", "v0.5.0": "b"}, "^0.4"),
                 ("v0.4.1", "a"))
self.assertEqual(
    select_latest_release_tag({"2026-02-08": "a", "2026-07-10": "b"}),
    ("2026-07-10", "b"),
)

rules = parse_snapshot(
    'return {{ "folke/snacks.nvim", version = "^2" },\n'
    '{ "example/pinned.nvim", commit = "' + "a" * 40 + '" },\n'
    '{ "example/conditional.nvim", commit = cond and "' + "b" * 40
    + '" or "' + "c" * 40 + '" }}'
)
self.assertEqual(rules["folke/snacks.nvim"].value, "^2")
self.assertEqual(rules["example/pinned.nvim"].value, "a" * 40)
self.assertEqual(rules["example/conditional.nvim"].kind, "unresolved")
```

Build a candidate manifest containing AstroNvim `^6`, pinned Snacks, and npm
Tailwind language server. Fake tags/snapshot/npm latest so the resolved target
values are AstroNvim SHA `1` repeated 40 times, Snacks SHA `3` repeated 40
times, and npm version `0.15.0`.

Add separate tests where the branch head is absent, the snapshot HTTP request
raises `OSError`, and an unsupported Mason ecosystem appears. Each result must
be `status: unresolved` with a component-specific reason while other components
remain resolved.

Add one deterministic integration test backed by a temporary bare Git remote.
Create two commits and a stable tag in a disposable working repository, push
them to the bare remote, and assert `RemoteClient.head` and
`RemoteClient.tags` return the expected SHA values through `git ls-remote`.
Snapshot the source checkout `HEAD` and status before/after to prove the client
does not mutate it.

Run: `python3 -m unittest tests.skills.test_nvim_update_brief_targets -v`

Expected: FAIL because `versions.py` and `remotes.py` are absent.

- [ ] **Step 2: Implement static version/snapshot rules**

Create `versions.py` with:

```python
@dataclass(frozen=True)
class Version:
    major: int
    minor: int
    patch: int
    prerelease: str | None

@dataclass(frozen=True)
class SnapshotRule:
    kind: str
    value: str | None
    reason: str | None = None
```

Parse `vMAJOR[.MINOR][.PATCH][-PRERELEASE]`. Implement caret ranges exactly:

```python
^6     => >= 6.0.0 and < 7.0.0
^0.4   => >= 0.4.0 and < 0.5.0
^0.0.3 => >= 0.0.3 and < 0.0.4
```

Exclude prereleases. `parse_astronvim_policy` reads only
`lua/lazy_setup.lua`, searches the 900 characters following
`AstroNvim/AstroNvim`, and returns the static version plus pin behavior
(`true`, `false`, or `nil` where `nil` means pinned when versioned).

`parse_snapshot` parses one table entry per line. A `version` produces a
version rule, one literal 40-hex commit produces a commit rule, and multiple
literal commits produce:

```python
SnapshotRule("unresolved", None, "snapshot commit depends on runtime evaluation")
```

`select_latest_release_tag` first uses stable semantic versions and otherwise
accepts strict `YYYY-MM-DD` tags, sorting them as calendar dates. Use it for
GitHub-backed Mason packages so tools such as Marksman are not silently lost.

- [ ] **Step 3: Implement non-mutating remote target resolution**

`RemoteClient` must use:

```python
subprocess.run(["git", "ls-remote", *arguments, remote],
               check=False, capture_output=True, text=True)
```

and HTTP GET with `urllib.request` plus a 20-second timeout. Never fetch into an
installed repository.

`resolve_targets` must:

1. Resolve the newest stable AstroNvim tag satisfying the root constraint.
2. GET the target commit's `lua/astronvim/lazy_snapshot.lua`.
3. Resolve snapshot version/commit rules for pinned core plugins.
4. Resolve non-snapshot plugins from the locked branch head.
5. Add GitHub `BASE...TARGET` comparison URLs.
6. Resolve npm PURLs through
   `https://registry.npmjs.org/{quoted-package}/latest`.
7. Resolve GitHub Mason PURLs through stable semver or ISO-date remote tags.
8. Return `{"status":"unresolved","reason":"..."}` for ambiguity or failure.

Update the local manifest with:

```python
version, pinned = parse_astronvim_policy(paths.config_dir)
"astronvim_policy": {"version": version, "pin_plugins": pinned}
```

Update the CLI:

```python
manifest = resolve_targets(build_local_manifest(paths), RemoteClient())
```

- [ ] **Step 4: Verify and commit target resolution**

```bash
python3 -m unittest \
  tests.skills.test_nvim_update_brief_discovery \
  tests.skills.test_nvim_update_brief_targets -v
rg -n 'subprocess.run|subprocess.check' .agents/skills/zimakki-nvim-update-brief/scripts
git add .agents/skills/zimakki-nvim-update-brief/scripts tests/skills/test_nvim_update_brief_targets.py
git commit -m "feat: resolve compatible Neovim update targets"
```

Expected: tests PASS; remote code contains `ls-remote` and no Git mutation,
Lazy command, or Mason command.

---

### Task 3: Add per-config coverage memory

**Files:**

- Create: `scripts/update_brief/state.py`
- Modify: `scripts/collect_updates.py`
- Create: `tests/skills/test_nvim_update_brief_state.py`

**Interfaces:**

- `config_id(runtime) -> str`
- `load_state(path)`, `apply_coverage(manifest, state)`
- `advance_state(state_path, manifest, coverage, report_path)`
- Adds `baseline`, `baseline_source`, and `has_uncovered_change`.

- [ ] **Step 1: Write failing state tests**

Use a one-plugin manifest and assert:

```python
first = apply_coverage(manifest(installed="a", target="b"), empty_state())
self.assertEqual(first["lazy"][0]["baseline"], "a")
self.assertEqual(first["lazy"][0]["baseline_source"], "installed")
self.assertTrue(first["lazy"][0]["has_uncovered_change"])

state = state_with_coverage("b")
updated_first = apply_coverage(manifest(installed="c", target="d"), state)
self.assertEqual(updated_first["lazy"][0]["baseline"], "b")
self.assertEqual(updated_first["lazy"][0]["baseline_source"], "coverage")

already_seen = apply_coverage(manifest(installed="a", target="b"), state)
self.assertFalse(already_seen["lazy"][0]["has_uncovered_change"])
```

Also assert `advance_state` rejects a `covered_through` value different from
the manifest target and preserves a second config entry. Add separate tests
that:

- a Mason target equal to the previous covered version is not uncovered;
- deferred components keep their prior coverage and record the latest reason;
- successful coverage removes that component from the deferred map;
- corrupt state is copied to `state.json.corrupt.UTCSTAMP` and treated as empty;
- the successful writer calls `os.replace`, leaves valid JSON, and leaves no
  temporary file in the state directory.

Run: `python3 -m unittest tests.skills.test_nvim_update_brief_state -v`

Expected: FAIL because `state.py` is absent.

- [ ] **Step 2: Implement state selection and atomic writes**

Use this state root:

```python
{"schema_version": 1, "configs": {}}
```

Compute config ID as the first 20 hex characters of SHA-256 over
`app_name:resolved-config-dir`. For each component:

```python
previous = config_state.get("components", {}).get(component_id, {}).get("covered_through")
baseline = previous if isinstance(previous, str) else installed_value
baseline_source = "coverage" if isinstance(previous, str) else "installed"
has_uncovered_change = target["status"] == "resolved" and baseline != target["value"]
```

`advance_state` must require every uncovered manifest component exactly once in
either `covered` or `deferred`, verify each coverage target exactly equals the
manifest target, accept only `featured`, `sparkle`, or `quiet-maintenance`, preserve
other config entries, union adjacent project IDs, and maintain a `deferred`
object keyed by component ID with `reason` and `attempted_at`. Components
omitted from coverage retain both their prior covered revision and their newest
defer reason; a successfully covered component is removed from `deferred`.
Atomically write with `mkstemp`, `flush`, `fsync`, and `os.replace`. Invalid
JSON/schema raises `StateError`. Copy corrupt state to
`state.json.corrupt.UTCSTAMP`, start with empty state, and add that fact to
manifest warnings.

- [ ] **Step 3: Apply state during collection and commit**

```python
state_path = paths.brief_home / "state.json"
try:
    state = load_state(state_path)
except StateError as error:
    backup = backup_corrupt_state(state_path)
    manifest["warnings"].append(f"{error}; backed up to {backup}")
    state = empty_state()
manifest = apply_coverage(manifest, state)
```

Run:

```bash
python3 -m unittest \
  tests.skills.test_nvim_update_brief_discovery \
  tests.skills.test_nvim_update_brief_targets \
  tests.skills.test_nvim_update_brief_state -v
git add .agents/skills/zimakki-nvim-update-brief/scripts tests/skills/test_nvim_update_brief_state.py
git commit -m "feat: remember Neovim briefing coverage"
```

Expected: all tests PASS and state coverage is committed.

---

### Task 4: Make report finalization transactional and read-only

**Files:**

- Create: `scripts/{read_only_guard.py,finalize_report.py}`
- Create: `scripts/update_brief/{guard.py,html_report.py}`
- Create: `tests/skills/test_nvim_update_brief_guard.py`

**Interfaces:**

- `capture_guard(manifest) -> dict[str, object]`
- `compare_guard(before, after) -> list[str]`
- `validate_html(path) -> list[str]`
- `read_only_guard.py capture [--config PATH] [--brief-home PATH] --output B`
- `read_only_guard.py compare --manifest M --before B`
- `finalize_report.py --manifest M --coverage C --report H --before B --state S`

- [ ] **Step 1: Write failing guard tests**

Create temp lock/receipt files, capture, mutate, recapture, and assert:

```python
self.assertIn("lazy-lock.json checksum changed", differences)
self.assertIn(f"Mason receipt changed: {receipt}", differences)
```

Validate an HTML fixture with external `<script src>` returns
`external script source`. Validate a fixture containing `<title>`, inline
style/script, one `<section data-note id>`, and
`Feedback (0) — Copy for agent` returns no errors.

Run: `python3 -m unittest tests.skills.test_nvim_update_brief_guard -v`

Expected: FAIL because guard modules are absent.

- [ ] **Step 2: Implement protected snapshots**

`capture_guard` records:

```python
{
    "config_root": git_toplevel,
    "config_status": git_status_porcelain_z,
    "config_tree": tree_fingerprint(config_dir),
    "lazy_lock": sha256(config / "lazy-lock.json"),
    "plugins": {
        component_id: {
            "head": git_head,
            "status": git_status_porcelain_z,
            "tree": tree_fingerprint(install_dir),
        }
    },
    "mason_receipts": {absolute_receipt_path: sha256(receipt)}
}
```

`tree_fingerprint` deterministically hashes sorted relative paths, symlink
targets, file modes, and regular-file contents while excluding `.git`
directories. This catches content changes even when a worktree already had the
same dirty-status labels before the run.

`compare_guard` emits exact human-readable differences for config root/status/
tree, lock checksum, plugin head/status/tree, and receipt checksum. The CLI
`capture` command calls `resolve_runtime` and `build_local_manifest` itself,
then writes the snapshot before the network-aware collector runs. It accepts
the same `--config` and `--brief-home` resolution options as the collector.
`compare` loads the final candidate manifest, prints
`protected Neovim state is unchanged`, or exits 1 with every difference.

- [ ] **Step 3: Implement HTML validation and finalization**

Use `html.parser.HTMLParser`. Require `<title>`, at least one
`section[data-note][id]`, and the feedback control. Reject external script
sources, stylesheet links, and image sources not beginning with `data:`.
External `<a href>` source links remain allowed.

`finalize_report.py` must execute in this order:

```python
errors = validate_html(report)
errors.extend(compare_guard(before, capture_guard(manifest)))
if errors:
    print("\n".join(errors), file=sys.stderr)
    return 1
advance_state(state_path, manifest, coverage, report)
return 0
```

Thus state cannot advance before both report and protected-state checks pass.

Add an integration test that invokes guard capture first, runs the collector
with a fake `RemoteClient`, and invokes compare. Assert the before file's mtime
precedes the manifest's mtime and that compare succeeds. Mutate the lockfile in
a second test and assert finalization returns 1 while `state.json` remains
absent.

- [ ] **Step 4: Verify and commit the transaction boundary**

```bash
python3 -m unittest discover -s tests/skills -p 'test_nvim_update_brief_*.py' -v
git add .agents/skills/zimakki-nvim-update-brief/scripts tests/skills/test_nvim_update_brief_guard.py
git commit -m "feat: enforce read-only Neovim brief runs"
```

Expected: all tests PASS.

---

### Task 5: Write the learning-first orchestration skill

**Files:**

- Modify: `.agents/skills/zimakki-nvim-update-brief/SKILL.md`
- Create: `.agents/skills/zimakki-nvim-update-brief/references/{contracts.md,editorial-policy.md}`
- Modify: `.agents/skills/zimakki-nvim-update-brief/agents/openai.yaml`
- Create: `tests/skills/test_nvim_update_brief_skill.py`

**Interfaces:**

- Consumes the three CLIs and JSON artifacts.
- Produces a mandatory `zimakki-html-doc` subagent prompt.
- Produces evidence and coverage contracts shared across agents.

- [ ] **Step 1: Write failing workflow-contract tests**

Assert:

```python
workflow = skill.split("## Workflow", 1)[1]
ordered = [
    "read_only_guard.py capture",
    "collect_updates.py",
    "zimakki-html-doc",
    "finalize_report.py",
]
self.assertEqual([workflow.index(value) for value in ordered],
                 sorted(workflow.index(value) for value in ordered))
self.assertIn("dedicated subagent", skill)
self.assertIn("parallel research subagents", skill)
self.assertIn("Never run `:Lazy", skill)
self.assertIn("Never run Mason", skill)
self.assertRegex(editorial, r"(?i)at most seven")
self.assertRegex(editorial, r"(?i)do not pad")
self.assertRegex(editorial, r"(?i)routine bug fixes")
```

Also assert `contracts.md` has Candidate manifest, Evidence bundle, Coverage
disposition, and Persistent state headings with no incomplete-work markers.

Run: `python3 -m unittest tests.skills.test_nvim_update_brief_skill -v`

Expected: FAIL against the interim skill.

- [ ] **Step 2: Write contracts and editorial policy**

`contracts.md` must define concrete schema-1 JSON examples:

```json
{
  "candidate": {
    "component_id": "lazy:folke/snacks.nvim",
    "baseline": "1111111111111111111111111111111111111111",
    "target": {
      "status": "resolved",
      "value": "2222222222222222222222222222222222222222"
    },
    "has_uncovered_change": true,
    "comparison_url": "https://github.com/folke/snacks.nvim/compare/1111111111111111111111111111111111111111...2222222222222222222222222222222222222222"
  },
  "evidence": {
    "headline": "A capability-oriented headline",
    "now_possible": "A concrete new action",
    "why_it_matters": "The workflow benefit",
    "availability": "opt-in after updating",
    "try_it": ["First concrete step"],
    "sources": [{
      "url": "https://github.com/folke/snacks.nvim/releases/tag/v2.4.0",
      "supports": "Exact capability claim"
    }],
    "visual": {
      "kind": "screenshot",
      "path": "/tmp/zimakki-nvim-update-brief-fixture/snacks.png",
      "source_url": "https://github.com/folke/snacks.nvim/releases/tag/v2.4.0"
    }
  },
  "coverage": {
    "component_id": "lazy:folke/snacks.nvim",
    "covered_through": "2222222222222222222222222222222222222222",
    "disposition": "featured"
  }
}
```

Allowed dispositions: `featured`, `sparkle`, `quiet-maintenance`. Deferred or
partially researched components are omitted from `covered` and recorded under
`deferred` instead.

Define `coverage.json` as a standalone finalization artifact:

```json
{
  "schema_version": 1,
  "covered": [{
    "component_id": "lazy:folke/snacks.nvim",
    "covered_through": "2222222222222222222222222222222222222222",
    "disposition": "featured"
  }],
  "deferred": [{
    "component_id": "mason:marksman",
    "reason": "upstream comparison was unavailable"
  }],
  "adjacent": ["owner/newly-featured-plugin"]
}
```

Every manifest component with `has_uncovered_change: true` must appear exactly
once in either `covered` or `deferred`. `advance_state` rejects duplicates,
unknown component IDs, missing dispositions/reasons, or a coverage target that
does not exactly match the resolved candidate target.

Define persistent state with the exact shape:

```json
{
  "schema_version": 1,
  "configs": {
    "e4f2d58a6c45a312bb12": {
      "app_name": "astronvim_v6",
      "config_dir": "/Users/zimakki/code/zimakki/astronvim_v6",
      "components": {
        "lazy:folke/snacks.nvim": {
          "covered_through": "2222222222222222222222222222222222222222",
          "installed_at_report": "1111111111111111111111111111111111111111",
          "disposition": "featured",
          "report": "/Users/zimakki/.local/share/zimakki-nvim-update-brief/reports/2026-07-21-1200-whats-new.html"
        }
      },
      "deferred": {
        "mason:marksman": {
          "reason": "upstream comparison was unavailable",
          "attempted_at": "2026-07-21T12:00:00+00:00"
        }
      },
      "adjacent": ["owner/previously-featured-plugin"],
      "last_report": "/Users/zimakki/.local/share/zimakki-nvim-update-brief/reports/2026-07-21-1200-whats-new.html",
      "generated_at": "2026-07-21T12:00:00+00:00"
    }
  }
}
```

State advancement must accept only the three allowed dispositions, retain the
union of previously featured adjacent project IDs, preserve covered revisions
for deferred components, and clear a defer record after successful coverage.

`editorial-policy.md` must rank new workflows, visible simplification, local
relevance, tryability, and strong evidence in that order. It must explicitly:

- cap primary discoveries at seven and forbid padding;
- explain what a change enables instead of copying release prose;
- suppress routine fixes, dependency bumps, refactors, release automation, and
  invisible maintenance;
- distinguish automatic, opt-in, and conceptual try-it examples;
- use an attributed maintainer screenshot, an honest diagram/example, or no
  visual—never fabricated UI;
- limit adjacent discoveries to two and forbid trend-list filler;
- attach a primary source to every factual capability claim.
- verify that each Git baseline reaches its target through the authoritative
  compare result; defer `behind`, `diverged`, replaced, or unverifiable history
  without advancing coverage.

Require the HTML subagent to use this information architecture:

1. Title, coverage period, and one-sentence purpose.
2. At-a-glance visual containing up to seven strongest discoveries.
3. New shiny things, one linked deep dive per primary discovery.
4. Smaller sparkles.
5. Worth discovering, omitted or limited to two items.
6. Quiet maintenance as collapsed counts only.
7. Brief heads-up only when necessary for a highlight.
8. Coverage, deferred components, and primary sources.

When no candidate clears the threshold, produce an honest quiet-cycle brief
instead of inventing a highlight.

- [ ] **Step 3: Replace SKILL.md with the complete workflow**

Required sequence and commands:

```markdown
1. Resolve config and UTC timestamp. Create
   `BRIEF_HOME/runs/YYYYMMDDTHHMMSSZ/` and
   `BRIEF_HOME/reports/YYYY-MM-DD-HHMM-whats-new.html`.
2. Run `read_only_guard.py capture` before the network collector.
3. Run `collect_updates.py`.
4. Group and research only `has_uncovered_change: true` candidates from primary
   sources. When the candidate set benefits, use parallel research subagents;
   otherwise research locally. Research subagents are optional, but the final
   HTML subagent is not.
5. Write `evidence.json` and `coverage.json` using the contracts.
6. Select at most seven highlights without padding or fix-heavy detail.
7. Spawn a dedicated subagent with:

   Use $zimakki-html-doc to turn the evidence bundle path supplied in this
   prompt into the self-contained learning brief at the supplied report path.
   Do not add claims or discoveries. Preserve source attribution, embed
   approved screenshots, use diagrams only when they teach a real workflow,
   and run the complete zimakki-html-doc verification checklist.

8. Inspect laptop/narrow layouts and browser console.
9. Run `finalize_report.py` only after editorial and visual approval.
10. Open the report and summarize highlights/deferred components.
```

The skill must say that unavailable subagents, collection failure, HTML
failure, or guard failure preserve run artifacts and do not advance state.
It must create run/report paths from the UTC timestamp and pass their absolute
values to every command and subagent prompt.

For an HTTP, API, or source failure, retry at most twice, then defer only the
affected component. Never weaken the source requirement to fill the report.
Successful components may finalize while deferred components retain their
previous coverage.

- [ ] **Step 4: Regenerate interface metadata**

```bash
python3 /Users/zimakki/.codex/skills/.system/skill-creator/scripts/generate_openai_yaml.py \
  .agents/skills/zimakki-nvim-update-brief \
  --interface 'display_name=Neovim Update Brief' \
  --interface 'short_description=Learn what new Neovim updates enable' \
  --interface 'default_prompt=Use $zimakki-nvim-update-brief to create a read-only visual learning brief about new capabilities in my Neovim stack.'
```

Expected:

```yaml
interface:
  display_name: "Neovim Update Brief"
  short_description: "Learn what new Neovim updates enable"
  default_prompt: "Use $zimakki-nvim-update-brief to create a read-only visual learning brief about new capabilities in my Neovim stack."
```

- [ ] **Step 5: Verify and commit the complete skill**

```bash
python3 -m unittest discover -s tests/skills -p 'test_nvim_update_brief_*.py' -v
git add .agents/skills/zimakki-nvim-update-brief tests/skills/test_nvim_update_brief_skill.py
git commit -m "feat: add Neovim update briefing workflow"
```

Expected: all unit/contract tests PASS.

---

### Task 6: Validate, forward-test, and produce the first v6 brief

**Files:**

- Modify only if validation exposes a defect: files from Tasks 1–5.
- Runtime output: `~/.local/share/zimakki-nvim-update-brief/reports/*.html`
- Runtime state: `~/.local/share/zimakki-nvim-update-brief/state.json`

**Interfaces:**

- Produces global discovery links.
- Produces an isolated forward-test report.
- Produces the first verified production report and coverage state.

- [ ] **Step 1: Run repository and skill validation**

```bash
git rev-parse --git-dir
git rev-parse --git-common-dir
python3 -m unittest discover -s tests/skills -p 'test_nvim_update_brief_*.py' -v
scripts/maintenance/sync-agent-skills.sh
scripts/ci_checks.sh
```

Expected: canonical Git dir/common dir match; tests and repository CI PASS. The
initial live skill audit is expected to exit nonzero only for the three missing
discovery links for the new skill; repository CI still PASSes because it tests
discovery in an isolated temporary HOME.

Attempt:

```bash
python3 /Users/zimakki/.codex/skills/.system/skill-creator/scripts/quick_validate.py \
  .agents/skills/zimakki-nvim-update-brief
```

Current expected result: `ModuleNotFoundError: No module named 'yaml'`. Record
the secondary validator as unavailable; do not install PyYAML globally or
modify the system skill.

- [ ] **Step 2: Link and re-audit canonical skills**

```bash
scripts/maintenance/sync-agent-skills.sh --fix
scripts/maintenance/sync-agent-skills.sh
```

Expected: `zimakki-nvim-update-brief` resolves from `~/.agents/skills`,
`~/.claude/skills`, and `~/.codex/skills`; the second audit exits 0. Do not
commit generated home links/manifests.

- [ ] **Step 3: Forward-test with isolated state**

Run:

```bash
brief_forward_dir="$(mktemp -d /tmp/zimakki-nvim-update-brief-forward.XXXXXX)"
realpath "$brief_forward_dir"
```

Pass the exact path printed by `realpath` to a fresh subagent with no
conversation context:

```text
Use $zimakki-nvim-update-brief at
/Users/zimakki/code/zimakki/dotfiles/.agents/skills/zimakki-nvim-update-brief/SKILL.md
to create a read-only learning brief for
/Users/zimakki/.config/astronvim_v6. Use the isolated brief-home path supplied
after this sentence. Follow the skill exactly, including the dedicated
$zimakki-html-doc subagent. Do not update or edit Neovim.
```

Expected: the subagent independently follows guard → collector → research →
HTML subagent → finalizer. It selects zero to seven evidence-backed discoveries,
suppresses routine fixes, explains what capabilities enable, and advances only
temporary state.

- [ ] **Step 4: Review forward-test artifacts**

Reject and revise if any headline copies a release title, a primary discovery
is mainly a bug fix, a claim lacks a matching primary source, more than seven
discoveries appear, adjacent items are generic, a screenshot lacks attribution,
the HTML adds claims absent from evidence, or finalization precedes guard/report
verification. After a revision, rerun all tests and use a fresh temp directory
without leaking the prior result.

- [ ] **Step 5: Run the production skill**

Launch a fresh agent:

```text
Use $zimakki-nvim-update-brief to create the current learning brief for
/Users/zimakki/.config/astronvim_v6. Use the default report/state directory,
primary sources for technical claims, and a dedicated $zimakki-html-doc
subagent. Do not update or edit Neovim.
```

Expected: a timestamped standalone HTML report and atomically written state.

- [ ] **Step 6: Verify presentation and read-only state**

Open the returned report path with `open`. Check laptop and narrow widths,
console errors, at-a-glance placement, annotation affordances, feedback button,
embedded/attributed screenshots, source support, offline assets, and the
seven-item cap.

Confirm the production agent's finalizer output includes
`protected Neovim state is unchanged` before its successful state-advance
message. If it does not, treat the production run as failed and leave prior
coverage state unchanged.

- [ ] **Step 7: Commit validation fixes only when needed**

```bash
git add .agents/skills/zimakki-nvim-update-brief tests/skills
git commit -m "fix: harden Neovim update briefing skill"
```

Skip this commit when no tracked fix was required.

- [ ] **Step 8: Final verification**

```bash
python3 -m unittest discover -s tests/skills -p 'test_nvim_update_brief_*.py' -v
scripts/maintenance/sync-agent-skills.sh
scripts/ci_checks.sh
git status --short
```

Expected: tests and audits PASS, the skill is globally discoverable, the
worktree is clean, Neovim remains unchanged, and the first report exists outside
Git.
