#!/usr/bin/env python3
"""Replace repo-owned indirect dotfile links with direct declared-source links.

Mise deliberately treats two symlinks that resolve to the same source as
converged. During the app-oriented layout migration, that would leave HOME
depending on transitional root-level compatibility links forever. This helper
only rewrites an indirect link when its first hop is inside this repository and
its final resolution already equals the source declared in mise.toml.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tomllib


class RelinkError(Exception):
    """A safe, user-facing relink failure."""


@dataclass(frozen=True)
class IndirectLink:
    target: Path
    source: Path
    original_text: str


def is_within(path: Path, directory: Path) -> bool:
    try:
        path.relative_to(directory)
    except ValueError:
        return False
    return True


def lexical_link_target(link: Path, link_text: str) -> Path:
    candidate = Path(link_text)
    if not candidate.is_absolute():
        candidate = link.parent / candidate
    return Path(os.path.abspath(candidate))


def dotfile_source(entry: object) -> str:
    if isinstance(entry, str):
        return entry
    if isinstance(entry, dict) and isinstance(entry.get("source"), str):
        return entry["source"]
    raise RelinkError(f"Unsupported dotfile entry: {entry!r}")


def require_safe_checkout(repository: Path) -> None:
    guard = repository / "scripts/bootstrap/preflight.zsh"
    result = subprocess.run(
        ["zsh", str(guard), "--guard-only", str(repository)],
        check=False,
    )
    if result.returncode:
        raise RelinkError("canonical-checkout guard refused static-link migration")


def atomic_symlink(source: Path, target: Path) -> None:
    temporary: Path | None = None
    try:
        for _ in range(100):
            candidate = target.parent / (
                f".{target.name}.dotfiles-link-{os.getpid()}-{secrets.token_hex(4)}"
            )
            try:
                os.symlink(source, candidate)
            except FileExistsError:
                continue
            temporary = candidate
            break
        if temporary is None:
            raise RelinkError(f"Could not allocate a temporary link beside {target}")
        os.replace(temporary, target)
        temporary = None
        try:
            directory_fd = os.open(target.parent, os.O_RDONLY | os.O_DIRECTORY)
        except (AttributeError, OSError):
            return
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def classify_links(repository: Path, home: Path) -> tuple[list[IndirectLink], list[str]]:
    with (repository / "mise.toml").open("rb") as handle:
        config = tomllib.load(handle)

    indirect: list[IndirectLink] = []
    problems: list[str] = []
    for target_name, entry in config["dotfiles"].items():
        if not target_name.startswith("~/"):
            problems.append(f"unsupported non-HOME target in mise.toml: {target_name}")
            continue

        relative_target = Path(target_name.removeprefix("~/"))
        if relative_target.is_absolute() or ".." in relative_target.parts:
            problems.append(f"unsafe HOME target in mise.toml: {target_name}")
            continue
        target = home / relative_target
        source = Path(os.path.abspath(repository / dotfile_source(entry)))
        if not is_within(source, repository):
            problems.append(f"declared source escapes the repository: {source}")
            continue
        if not source.exists():
            problems.append(f"declared source is missing: {source}")
            continue
        if not target.is_symlink():
            state = "missing" if not target.exists() else "not a symlink"
            problems.append(f"static target is {state}: {target}")
            continue

        original_text = os.readlink(target)
        first_hop = lexical_link_target(target, original_text)
        if first_hop == source:
            continue

        try:
            final_target = target.resolve(strict=True)
            final_source = source.resolve(strict=True)
        except (OSError, RuntimeError) as error:
            problems.append(f"cannot resolve static link {target}: {error}")
            continue

        if final_target == final_source and is_within(first_hop, repository):
            indirect.append(IndirectLink(target, source, original_text))
        else:
            problems.append(
                f"refusing unrelated static link: {target} -> {original_text}"
            )

    return indirect, problems


def migrate_links(repository: Path, home: Path, check: bool) -> int:
    indirect, problems = classify_links(repository, home)
    if problems:
        for problem in problems:
            print(f"Static-link migration failed: {problem}", file=sys.stderr)
        return 2

    if check:
        if indirect:
            for link in indirect:
                print(
                    f"Indirect static link: {link.target} -> {link.original_text}",
                    file=sys.stderr,
                )
            return 1
        print("Static HOME links point directly to their declared sources.")
        return 0

    if not indirect:
        print("Static HOME links are already direct.")
        return 0

    require_safe_checkout(repository)

    # Re-check every first hop after the guard and before changing any target.
    for link in indirect:
        if not link.target.is_symlink() or os.readlink(link.target) != link.original_text:
            raise RelinkError(f"Static link changed during migration: {link.target}")

    for link in indirect:
        atomic_symlink(link.source, link.target)
        print(f"Relinked static config: {link.target} -> {link.source}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report indirect links without writing")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repository = Path(__file__).resolve().parents[2]
    home = Path.home()
    try:
        return migrate_links(repository, home, args.check)
    except (RelinkError, KeyError, OSError, tomllib.TOMLDecodeError) as error:
        print(f"Static-link migration failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
