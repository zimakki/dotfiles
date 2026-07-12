#!/usr/bin/env python3
"""Portable structural checks for the selective mise bootstrap contract."""
from pathlib import Path
import re
import tomllib

root = Path(__file__).resolve().parent.parent
config = tomllib.loads((root / "mise.toml").read_text())
assert config["min_version"] >= "2026.7.4"
assert len(config["tools"]) == 7
assert all(value != "latest" for value in config["tools"].values())
assert "packages" not in config["bootstrap"], "BrewFile must be the only package inventory"
assert "brew bundle" in config["bootstrap"]["hooks"]["pre-tools"]["run"]
assert "{{" not in config["bootstrap"]["hooks"]["pre-tools"]["run"]
assert len(config["dotfiles"]) == 19
assert "~/.config/lazygit/config.yml" not in config["dotfiles"]
for entry in config["dotfiles"].values():
    source = entry if isinstance(entry, str) else entry["source"]
    assert (root / source).exists(), source

defaults = config["bootstrap"]["macos"]
typed_count = sum(len(defaults[group]) for group in ("keyboard", "finder", "dock"))
typed_count += sum(len(values) for values in defaults["defaults"].values())
assert typed_count == 12

legacy_links = (root / "setup_sim_links.zsh").read_text()
assert len(re.findall(r'^\s+"[^\n]+:[^\n]+"$', legacy_links, re.M)) == 1
legacy_defaults = (root / "macos_defaults.sh").read_text()
assert len(re.findall(r"^defaults .* write ", legacy_defaults, re.M)) == 1

zshrc = (root / "zshrc").read_text()
assert 'eval "$(mise activate zsh)"' in zshrc
assert "/opt/homebrew/bin/mise" not in zshrc
assert "KERL_BUILD_DOCS" in (root / "zshenv").read_text()
