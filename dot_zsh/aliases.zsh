if (( $+commands[eza] )); then
  alias ls='eza -al --color=always --group-directories-first'
  alias la='eza -a --color=always --group-directories-first'
  alias ll='eza -l --color=always --group-directories-first'
fi
alias l='ls'
alias du='du -h -c'
alias vim='nvim'
alias n='nvim'
alias python='python3'
alias whitespace="sed 's/ /␣/g;s/\t/￫/g;s/\r/§/g;s/$/¬/g'"
alias g='git'
alias gs='git status'
alias gd='git diff -w --ignore-blank-lines'
