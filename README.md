# dotfiles

This repo manages my macOS dotfiles, terminal/TUI app configs, shared theme
assets, and project-local Claude skills. The symlink manifest in
`setup_sim_links.zsh` is the source of truth for machine-linked files.

Managed areas currently include:

- Shell: `.zshenv`, `.zshrc`, Starship, Atuin, zsh syntax highlighting
- Terminal/TUI tools: Ghostty, Lazygit, Hunk, bat, Television, Warp keybindings/themes
- Developer tooling: Git config, global gitignore, mise global tools, Claude settings
- System/app config: Karabiner and Homebrew bundle

Not every tracked config-like artifact is symlinked. `.claude/skills/` is loaded
as project-local Claude skills from the repo, while `~/.claude/skills` remains
the shared agent skills directory. `raycast.rayconfig` is a manual Raycast import
artifact and should not be symlinked.

## Get up and running

> note: I have not run this on a new computer so I imagine I will have to install everything I need before I am really able to use this file.

I'm currently running [AstroVim](https://astronvim.com/) and you can find the astro vim config here: [AstroNvim](https://github.com/zimakki/AstroNvim)

### 1. Install all the brew stuff

Run the below command from the root of this folder:
`brew bundle install`

### 2. Sim links

To run `setup_sim_links.zsh`:

- make sure you give the file permissions:
  `chmod +x ./setup_sim_links.zsh`
- run it!:
  `./setup_sim_links.zsh`

### Theme

The terminal/TUI theme target is Catppuccin Mocha, using the Mauve accent where
an app asks for an accent choice.
