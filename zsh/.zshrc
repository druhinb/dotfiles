# Enable Powerlevel10k instant prompt — near top of file
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Conda / Mamba initialization (portable)
__conda_setup="$(command -v conda >/dev/null && conda 'shell.zsh' 'hook' 2> /dev/null || true)"
if [ -n "$__conda_setup" ]; then
  eval "$__conda_setup"
else
  # fallback to reading from known install paths
  for _m in "$HOME/mambaforge" "$HOME/miniforge3" "$HOME/miniconda3"; do
    if [ -f "$_m/etc/profile.d/conda.sh" ]; then
      source "$_m/etc/profile.d/conda.sh"
      break
    fi
  done
fi
unset __conda_setup

# Source Powerlevel10k theme
if [ -f /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme ]; then
  source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
fi
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# History setup
HISTFILE=${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history
mkdir -p "$(dirname "$HISTFILE")"
SAVEHIST=1000
HISTSIZE=999
setopt share_history hist_expire_dups_first hist_ignore_dups hist_verify

bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Source autosuggestions and syntax highlighting if present
if [ -r /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [ -r /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Eza alias (better ls)
alias ls="eza --icons=always -a"

# Zoxide (better cd)
eval "$(zoxide init zsh)"
alias cd="z"           # optional: you can uncomment this if you prefer cd → z

# NVM (if installed via Homebrew or common path)
export NVM_DIR="$HOME/.nvm"
if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
  . "/opt/homebrew/opt/nvm/nvm.sh"
fi
if [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ]; then
  . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
fi

# The Fuck aliases (deduplicated)
eval "$(thefuck --alias fk)"
eval "$(thefuck --alias oops)"

# Apache Ant custom path (if you need it)
export ANT_HOME="$HOME/opt/apache-ant-1.10.15"
export PATH="$ANT_HOME/bin:$PATH"

# Local overrides (machine specific or secrets)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"

# Initialize zsh completion system
autoload -Uz compinit
compinit

# Makefile target completion
function _makefile_targets {
    local -a targets
    targets=($(command make -qp 2>/dev/null | awk -F':' '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ && !/^Makefile/ {split($1,A,/ /);for(i in A)print A[i]}' | sort -u))
    compadd $targets
}

compdef _makefile_targets make

