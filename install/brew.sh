#!/bin/sh
# give me what I need, brew!
brew update

# cli tools
brew install tree wget ripgrep procs tldr exa

# development tools
brew install node
brew install git
brew install reattach-to-user-namespace
brew install tmux
brew install fzf
brew install zsh
brew install antigen
brew install romkatv/powerlevel10k/powerlevel10k
brew install --build-from-source --HEAD luajit
brew install --build-from-source --HEAD neovim
brew install git-delta
brew install stow
brew cask install alacritty
