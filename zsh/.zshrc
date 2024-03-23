# Path to Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# We use starship, so we disable the OMZ theme (or leave it empty)
ZSH_THEME=""

# Plugins
# git: standard
# zsh-autosuggestions: custom
# zsh-syntax-highlighting: custom
# fzf-tab: custom
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf-tab you-should-use zsh-bat)

# Auto-install plugins if missing
if [[ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi
if [[ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi
if [[ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab ]]; then
    git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
fi
if [[ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use ]]; then
    echo "Installing you-should-use..."
    git clone https://github.com/MichaelAquilina/zsh-you-should-use ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use
fi
if [[ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-bat ]]; then
    echo "Installing zsh-bat..."
       git clone https://github.com/fdellwing/zsh-bat.git $ZSH_CUSTOM/plugins/zsh-bat
fi

source $ZSH/oh-my-zsh.sh

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

# History setup (Preserve user's custom location)
HISTFILE=${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history
mkdir -p "$(dirname "$HISTFILE")"
SAVEHIST=1000
HISTSIZE=999
setopt share_history hist_expire_dups_first hist_ignore_dups hist_verify

# Aliases
alias cat="bat"
alias ls="eza --icons=always -a"
alias gs="git status"
# cd is handled by zoxide below

# Zoxide
eval "$(zoxide init zsh)"
alias cd="z"

# NVM
export NVM_DIR="$HOME/.nvm"
if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
  . "/opt/homebrew/opt/nvm/nvm.sh"
fi
if [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ]; then
  . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
fi

# TheFuck
eval "$(thefuck --alias fk)"
eval "$(thefuck --alias oops)"

# Ant
export ANT_HOME="$HOME/opt/apache-ant-1.10.15"
export PATH="$ANT_HOME/bin:$PATH"

# Local overrides
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# Atuin
. "$HOME/.atuin/bin/env"
eval "$(atuin init zsh)"

# Starship (Must be at the end to override OMZ prompt)
eval "$(starship init zsh)"

# FZF Tab Configuration
# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# preview directory's content with eza when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
# switch group using < and >
zstyle ':fzf-tab:*' switch-group '<' '>'

# Makefile completion
function _makefile_targets {
    local -a targets
    targets=($(command make -qp 2>/dev/null | awk -F':' '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ && !/^Makefile/ {split($1,A,/ /);for(i in A)print A[i]}' | sort -u))
    compadd $targets
}
compdef _makefile_targets make

bindkey -v
export keytimeout=1

bindkey -M viins '^Y' autosuggest-accept
bindkey '^Y' autosuggest-accept
