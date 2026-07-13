#!/usr/bin/env python3
"""Apply a repository-owned JSON overlay to app-managed JSON config.

Dictionary keys merge recursively; lists and scalar values replace their
counterparts. Keys that exist only in the live target are preserved.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
from typing import Any


class OverlayError(Exception):
    """A safe, user-facing overlay failure."""


def merge_json(existing: Any, managed: Any) -> Any:
    if isinstance(existing, dict) and isinstance(managed, dict):
        merged = dict(existing)
        for key, value in managed.items():
            merged[key] = merge_json(existing.get(key), value)
        return merged
    if isinstance(managed, dict):
        return {key: merge_json(None, value) for key, value in managed.items()}
    return managed


def is_within(path: Path, directory: Path) -> bool:
    try:
        path.relative_to(directory)
    except ValueError:
        return False
    return True


def load_json(path: Path, *, missing: Any = None) -> Any:
    if not path.exists():
        return missing
    if not path.is_file():
        raise OverlayError(f"JSON path is not a regular file: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise OverlayError(f"Cannot read valid JSON from {path}: {error}") from error


def atomic_write_json(target: Path, value: Any, mode: int) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        dir=target.parent,
        prefix=f".{target.name}.",
        suffix=".tmp",
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, target)
        try:
            directory_fd = os.open(target.parent, os.O_RDONLY | os.O_DIRECTORY)
        except (AttributeError, OSError):
            return
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        temporary.unlink(missing_ok=True)


def require_safe_checkout() -> None:
    repository = Path(__file__).resolve().parents[2]
    guard = repository / "scripts/bootstrap/preflight.zsh"
    result = subprocess.run(
        ["zsh", str(guard), "--guard-only", str(repository)],
        check=False,
    )
    if result.returncode:
        raise OverlayError("canonical-checkout guard refused JSON mutation")


def apply_overlay(source: Path, target: Path, repo_root: Path, check: bool) -> int:
    repo_root = repo_root.resolve(strict=True)
    source = source.resolve(strict=True)
    if not is_within(source, repo_root):
        raise OverlayError(f"Managed overlay must live inside the repository: {source}")

    managed = load_json(source)
    if target.is_symlink():
        raise OverlayError(
            f"Refusing symlink target; app-owned JSON must be a regular file: {target}"
        )
    if target.exists():
        existing = load_json(target)
        mode = stat.S_IMODE(target.stat().st_mode)
    else:
        existing = {}
        mode = 0o600

    merged = merge_json(existing, managed)
    converged = target.exists() and existing == merged
    if check:
        if converged:
            print(f"JSON overlay is current: {target}")
            return 0
        print(f"JSON overlay drift: {target}", file=sys.stderr)
        return 1

    if converged:
        print(f"JSON overlay unchanged: {target}")
        return 0

    require_safe_checkout()
    atomic_write_json(target, merged, mode)
    print(f"Applied JSON overlay: {target}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report drift without writing")
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help=argparse.SUPPRESS,
    )
    parser.add_argument("source", type=Path, help="managed JSON overlay in the repository")
    parser.add_argument("target", type=Path, help="live app-owned JSON file")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        return apply_overlay(args.source, args.target.expanduser(), args.repo_root, args.check)
    except (OverlayError, FileNotFoundError, OSError) as error:
        print(f"JSON overlay failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
