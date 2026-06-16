# Path
export PATH="$HOME/.local/bin:$HOME/opt/apache-ant-1.10.15/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"
export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:"
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"

# Oh My Zsh
ZSH_THEME=""
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf-tab you-should-use)
export ZSH="$HOME/.oh-my-zsh"

ZSH_AUTOSUGGEST_MANUAL_REBIND=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_HIGHLIGHT_MAXLENGTH=512

source $ZSH/oh-my-zsh.sh

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
    git clone https://github.com/MichaelAquilina/zsh-you-should-use ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use
fi

# Conda / Mamba initialization (portable)
__conda_setup="$(command -v conda >/dev/null && conda 'shell.zsh' 'hook' 2> /dev/null || true)"
if [ -n "$__conda_setup" ]; then
  eval "$__conda_setup"
else
  for _m in "$HOME/mambaforge" "$HOME/miniforge3" "$HOME/miniconda3"; do
    if [ -f "$_m/etc/profile.d/conda.sh" ]; then
      source "$_m/etc/profile.d/conda.sh"
      break
    fi
  done
fi
unset __conda_setup

# History
HISTFILE=${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history
mkdir -p "$(dirname "$HISTFILE")"
SAVEHIST=1000
HISTSIZE=999
setopt share_history hist_expire_dups_first hist_ignore_dups hist_verify

# Clipboard: pipe anything to `y` to copy via OSC 52 (works over SSH, tmux, mosh)
y() {
  local data
  if [[ -t 0 ]]; then
    data="$*"
  else
    data=$(cat)
  fi
  local encoded=$(printf '%s' "$data" | base64 | tr -d '\n')
  printf '\e]52;c;%s\a' "$encoded" > /dev/tty
}

# Aliases
alias cat="bat"
alias ls="eza --icons=always -a"
alias gs="git status"
alias download='f(){aria2c -x16 -s16 $1};f'
alias lg='lazygit'

# NVM (lazy-loaded)
export NVM_DIR="$HOME/.nvm"
_nvm_lazy_load() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
}
nvm() { _nvm_lazy_load; nvm "$@"; }
node() { _nvm_lazy_load; node "$@"; }
npm() { _nvm_lazy_load; npm "$@"; }
npx() { _nvm_lazy_load; npx "$@"; }

# Local overrides
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# Starship prompt (must be near end to override OMZ prompt)
if command -v starship >/dev/null 2>&1 && [[ ${TERM:-dumb} != dumb ]]; then
  eval "$(starship init zsh)"
fi

# FZF Tab Configuration
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:*' switch-group '<' '>'

# Makefile completion
function _makefile_targets {
    local -a targets
    targets=($(command make -qp 2>/dev/null | awk -F':' '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ && !/^Makefile/ {split($1,A,/ /);for(i in A)print A[i]}' | sort -u))
    compadd $targets
}
compdef _makefile_targets make

# Atuin
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi

# Vi mode + keybindings (after plugin widgets are defined)
bindkey -v
KEYTIMEOUT=1

if (( $+widgets[atuin-search] )); then
  bindkey '^n' atuin-search
  bindkey '^p' atuin-search
  bindkey -M viins '^n' atuin-search
  bindkey -M viins '^p' atuin-search
fi
if (( $+widgets[autosuggest-accept] )); then
  bindkey -M viins '^Y' autosuggest-accept
  bindkey '^Y' autosuggest-accept
fi



export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"

tmux-ssh() {
    if [ -z "$1" ]; then
        echo "Error: Target host missing. Usage: tmux-ssh user@host"
        return 1
    fi

    local HOST="$1"
    local SESSION_NAME="ssh-${HOST//./-}" # Replaces dots with dashes for valid session name

    # 1. Create a detached session where the initial window runs SSH
    tmux new-session -d -s "$SESSION_NAME" "ssh $HOST"

    # 2. Force all future windows/splits in THIS session to run SSH automatically
    tmux set-option -t "$SESSION_NAME" default-command "ssh $HOST"

    # 3. Attach to the newly constructed session
    tmux attach-session -t "$SESSION_NAME"
}

eval "$(fnm env --use-on-cd --shell zsh)"

# fnm
FNM_PATH="/home/coder/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  eval "$(fnm env --shell zsh)"
fi

export _ZO_DOCTOR=0
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd="z"
fi

