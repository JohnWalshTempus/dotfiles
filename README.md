# dotfiles

macOS shell, git, tmux and kitty configuration managed with [chezmoi](https://www.chezmoi.io): zsh with [antidote](https://github.com/mattmc3/antidote) and [starship](https://starship.rs), a templated git config, tmux with a `C-Space` prefix and vi copy-mode, and kitty.

## Bootstrap

```sh
brew install chezmoi
chezmoi init JohnWalshTempus
chezmoi diff
chezmoi apply -v
```

`chezmoi diff` shows what will change before anything is written; `apply` overwrites `~/.zshrc`, `~/.gitconfig` and `~/.tmux.conf`.

One-liner:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply JohnWalshTempus
```

Non-interactive:

```sh
chezmoi init JohnWalshTempus --promptBool "work machine=false" --promptString "git name=Jane Doe,git email=jane@example.com"
```

Add `--one-shot` to take a copy without keeping any chezmoi state.

Update later with `chezmoi update`; refresh the antidote checkout with `chezmoi apply -R`.

## Prompts

Answers are stored in `~/.config/chezmoi/chezmoi.toml` and never committed.

| Prompt | Data key | Controls |
|---|---|---|
| work machine | `work` | Enables the optional `workRepoUrl` prompt |
| git name | `name` | `user.name` |
| git email | `email` | `user.email` |
| gpg signing key id | `signingKey` | `user.signingkey` and `commit.gpgsign = true`; blank disables signing |
| github username | `githubUser` | `[github] user`; blank omits the section |
| work layer git ssh url | `workRepoUrl` | When set on a work machine, clones that repo into `~/.zsh/work` |

## Local layers

These are never managed by this repo and are picked up when present:

- `~/.zshrc.local`, sourced near the end of `~/.zshrc`
- `~/.zsh/work/*.zsh`, sourced before `~/.local/bin` is added to `PATH`
- `~/.gitconfig.local`, included last so its values win

## Optional dependencies

```sh
brew install starship eza git-delta neovim tmux
brew install --cask kitty font-blex-mono-nerd-font
```

Each is optional: without eza `ls` stays plain, without delta the git pager sections are omitted, and without starship the default prompt is used. nvm, pyenv and sdkman hooks are no-ops when the tool is absent. Installing delta or git-lfs later needs a `chezmoi apply` to render their git sections.
