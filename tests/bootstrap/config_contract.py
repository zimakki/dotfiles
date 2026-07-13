#!/usr/bin/env python3
"""Portable structural checks for the declarative bootstrap contract."""

from __future__ import annotations

import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tomllib


ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = ROOT / "mise.toml"
CONFIG = tomllib.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def semantic_version(value: str) -> tuple[int, ...]:
    match = re.fullmatch(r"(\d+(?:\.\d+)+)(?:[-+].*)?", value)
    assert match, f"not a parseable semantic version: {value!r}"
    return tuple(int(component) for component in match.group(1).split("."))


def dotfile_source(entry: object) -> str:
    if isinstance(entry, str):
        return entry
    assert isinstance(entry, dict) and isinstance(entry.get("source"), str), entry
    return entry["source"]


def source_for(target: str) -> Path:
    source = dotfile_source(CONFIG["dotfiles"][target])
    return ROOT / source


assert semantic_version(CONFIG["min_version"]) >= (2026, 7, 4)
assert CONFIG["settings"]["dotfiles"]["default_mode"] == "symlink"

tools = CONFIG["tools"]
assert {"node", "python", "elixir", "erlang"} <= tools.keys()
for name, value in tools.items():
    assert isinstance(value, str) and value, f"{name} must be pinned"
    assert value != "latest" and "*" not in value, f"{name} is not pinned: {value}"
    semantic_version(value)

bootstrap = CONFIG["bootstrap"]
assert "packages" not in bootstrap, "BrewFile must be the only package inventory"
pre_tools = bootstrap["hooks"]["pre-tools"]["run"]
assert "brew bundle" in pre_tools and "BrewFile" in pre_tools
assert "scripts/bootstrap/preflight.zsh" in pre_tools and "--guard-only" in pre_tools
assert pre_tools.index("--guard-only") < pre_tools.index("brew bundle")
assert "{{" not in pre_tools

pre_packages = bootstrap["hooks"]["pre-packages"]["run"]
assert "scripts/bootstrap/preflight.zsh" in pre_packages
assert "--guard-only" in pre_packages

pre_dotfiles = bootstrap["hooks"]["pre-dotfiles"]["run"]
assert "scripts/bootstrap/preflight.zsh" in pre_dotfiles
assert "--guard-only" in pre_dotfiles

pre_defaults = bootstrap["hooks"]["pre-defaults"]["run"]
assert "scripts/bootstrap/preflight.zsh" in pre_defaults
assert "--guard-only" in pre_defaults

dotfiles = CONFIG["dotfiles"]
assert dotfiles, "at least one static dotfile must be declared"
assert len(dotfiles) == len(set(dotfiles)), "dotfile targets must be unique"
assert "~/.config/lazygit/config.yml" not in dotfiles
assert "~/.claude/settings.json" not in dotfiles
assert "~/.config/karabiner/karabiner.json" not in dotfiles

root_source_exceptions = {"BrewFile", "mise.toml"}
seen_sources: set[str] = set()
for target, entry in dotfiles.items():
    assert target.startswith("~/"), f"dotfile target must be HOME-relative: {target}"
    pure_target = PurePosixPath(target.removeprefix("~/"))
    assert not pure_target.is_absolute() and ".." not in pure_target.parts, target
    source = dotfile_source(entry)
    pure_source = PurePosixPath(source)
    assert not pure_source.is_absolute() and ".." not in pure_source.parts, source
    assert source not in seen_sources, f"source is mapped more than once: {source}"
    seen_sources.add(source)
    assert source in root_source_exceptions or pure_source.parts[0] == "config", (
        f"application config belongs under config/: {source}"
    )
    source_path = ROOT / source
    assert source_path.exists(), f"missing dotfile source: {source}"
    subprocess.run(
        ["git", "-C", ROOT, "ls-files", "--error-unmatch", source],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

for managed_overlay in (
    ROOT / "config/claude/settings.json",
    ROOT / "config/karabiner/karabiner.json",
):
    assert managed_overlay.is_file(), managed_overlay
    assert str(managed_overlay.relative_to(ROOT)) not in seen_sources

root_symlinks = subprocess.run(
    ["git", "-C", ROOT, "ls-files", "-s"],
    check=True,
    capture_output=True,
    text=True,
).stdout.splitlines()
assert not any(
    line.startswith("120000 ") and "/" not in line.split("\t", 1)[1]
    for line in root_symlinks
), "root-level app config symlinks are not supported"

claude_overlay = json.loads((ROOT / "config/claude/settings.json").read_text())
assert "feedbackSurveyState" not in claude_overlay, "volatile Claude state is not overlay-owned"

bootstrap_task = CONFIG["tasks"]["bootstrap"]
assert bootstrap_task["dir"] == "{{cwd}}"
assert "MISE_CONFIG_ROOT" in bootstrap_task["run"]
assert "MISE_GLOBAL_CONFIG_FILE" in bootstrap_task["run"]
assert "scripts/bootstrap/exceptions.zsh" in bootstrap_task["run"]

macos = bootstrap["macos"]
for typed_group in ("keyboard", "finder", "dock"):
    assert isinstance(macos[typed_group], dict) and macos[typed_group]
    assert all(isinstance(value, (bool, int, float, str)) for value in macos[typed_group].values())
assert isinstance(macos["defaults"], dict) and macos["defaults"]
for domain, values in macos["defaults"].items():
    assert domain and isinstance(values, dict) and values
    assert all(isinstance(value, (bool, int, float, str)) for value in values.values())

zshrc = source_for("~/.zshrc").read_text(encoding="utf-8")
zshenv = source_for("~/.zshenv").read_text(encoding="utf-8")
assert 'eval "$(mise activate zsh)"' in zshrc
assert "/opt/homebrew/bin/mise" not in zshrc
assert "KERL_BUILD_DOCS" in zshenv
for target in ("~/.gitconfig", "~/.zshenv", "~/.zprofile", "~/.zshrc"):
    assert "/Users/" not in source_for(target).read_text(encoding="utf-8"), target

brewfile = (ROOT / "BrewFile").read_text(encoding="utf-8")
assert 'tap "zimakki/tap"' in brewfile
assert 'cask "zimakki/tap/inkwell"' in brewfile
assert 'cask "inkwell"' not in brewfile

required_scripts = (
    "scripts/bootstrap/preflight.zsh",
    "scripts/bootstrap/exceptions.zsh",
    "scripts/bootstrap/link-lazygit-config.zsh",
    "scripts/bootstrap/apply-macos-exceptions.zsh",
    "scripts/bootstrap/json-overlay.py",
    "scripts/bootstrap/verify.zsh",
    "scripts/maintenance/sync-agent-skills.sh",
    "tests/bootstrap/isolated.sh",
)
for relative in required_scripts:
    assert (ROOT / relative).is_file(), relative

obsolete_scripts = (
    "setup_sim_links.zsh",
    "macos_defaults.sh",
    "scripts/bootstrap_exceptions.zsh",
    "scripts/phase2_preflight.sh",
    "scripts/sync_agent_skills.sh",
    "scripts/test_bootstrap_config.py",
    "scripts/test_bootstrap_isolated.sh",
    "scripts/verify_setup.sh",
)
for relative in obsolete_scripts:
    assert not (ROOT / relative).exists(), f"obsolete bootstrap entry point remains: {relative}"
