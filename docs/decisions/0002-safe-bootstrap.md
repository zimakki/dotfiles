# ADR 0002: Keep bootstrap declarative, staged, and canonical-checkout only

- Status: Accepted
- Date: 2026-07-12

## Decision

Use `mise bootstrap` as the coordinator and keep ownership explicit:

```text
BrewFile ───────────────► packages and casks
mise.toml ──────────────► tools, static links, typed macOS defaults
scripts/bootstrap/ ─────► preflight, verification, narrow exceptions
scripts/maintenance/ ───► explicit maintenance tasks
tests/bootstrap/ ───────► contract and isolated behavior
```

Bootstrap must refuse to mutate the machine when invoked from a linked or
secondary worktree. Relative dotfile sources resolve from the active checkout;
linking them from a disposable worktree would break the machine when that
worktree is removed.

Apply changes in this order:

1. Run canonical-checkout and dependency preflight.
2. Preview the full operation.
3. Apply packages, tools, static links, and typed defaults through mise.
4. Run only the narrow exceptions mise cannot express.
5. Verify convergence twice after an apply.

Conflicts fail closed. Inspect live content before using any force option.
Scripts must propagate failures, avoid fixed destructive backup names, and be
safe to re-run.

## Exception boundary

- `scripts/bootstrap/link-lazygit-config.zsh` may resolve Lazygit's dynamic
  destination.
- `scripts/bootstrap/apply-macos-exceptions.zsh` may perform unsupported
  host-scoped defaults writes and restart affected apps when needed.
- `scripts/bootstrap/json-overlay.py` may merge repository-owned fragments into
  app-owned JSON without deleting unmanaged dictionary keys.
- `scripts/bootstrap/exceptions.zsh` coordinates those actions and agent-skill
  synchronization; it does not duplicate the package, link, or defaults
  manifests.

## Consequences

- A review of `BrewFile`, `mise.toml`, and the exception directory explains the
  machine setup.
- Disposable worktrees remain safe places to edit and test, not apply.
- Exact item counts and pinned versions are derived from manifests in tests;
  prose does not duplicate them.
- Recovery guidance stays in one current runbook rather than historical rollout
  documents.
