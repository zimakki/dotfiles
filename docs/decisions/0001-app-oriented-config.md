# ADR 0001: Organize configuration by app

- Status: Accepted
- Date: 2026-07-12

## Decision

Use `config/<app>/` as the canonical home for application and shell
configuration. The path should answer “which app owns this?” before it answers
“where does this land in `$HOME`?” `mise.toml` remains the destination map.

```text
config/
├── atuin/
│   ├── config.toml
│   └── themes/
├── git/
│   ├── config
│   └── ignore_global
├── hunk/config.toml
├── television/
├── warp/
│   ├── keybindings.yaml
│   └── themes/
└── zsh/
    ├── zshenv
    ├── zprofile
    ├── zshrc
    ├── hosts/
    ├── lib/
    └── themes/
```

App-specific themes stay with their apps. A shared palette does not make their
schemas or loading rules interchangeable.

## Configuration lifecycle

| Kind | Examples | Policy |
| --- | --- | --- |
| Stable, user-authored text | Atuin, Ghostty, Hunk, Git | Link from `config/<app>/` |
| App-mutated JSON | Claude, Karabiner | Recursively merge a repository-owned overlay into the live app-owned file |
| Opaque state/export | Raycast exports, caches, databases | Keep outside Git; restore through the app or secure external storage |
| Generated upstream defaults | Unmodified Television channels and templates | Do not vendor; track only intentional overrides |
| Secrets | API keys, tokens, password stores | Keep in 1Password or ignored local files; never commit |

## Consequences

- New config is discoverable without memorizing root-level naming conventions.
- `mise.toml` expresses installation destinations without forcing the source
  tree to mirror `$HOME`.
- Root-level app config is not an authoring location; canonical sources remain
  under `config/<app>/`.
- JSON overlays preserve live dictionary keys absent from the managed fragment.
  Managed lists and scalar values replace their live counterparts. Overlay
  application is atomic and tested separately from static links.
