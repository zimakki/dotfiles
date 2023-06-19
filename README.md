# dotfiles

Currently I have only a few of the dotfiles catered for:

- Brewfile
- .gitconfig
- .gitignore_global
- .zshrc

The plan is to have more...

## Get up and running

> note: I have not run this on a new computer so I imagine I will have to install everything I need before I am really able to use this file.

I'm currently running [AstroVim](https://astronvim.com/) and you can find the astro vim config here: [AstroNvim](https://github.com/zimakki/AstroNvim)

### 1. Install all the brew stuff

Run the below command from the root of this folder:
`brew bundle install`

### 2. Sim links

To run the `setup_sim_links.zsh`

- make sure you give the file permissions:
  `chmod +x ./setup_sim_links.zsh`
- run it!:
  `./setup_sim_links.zsh`
