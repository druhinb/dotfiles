# Interactive shell configuration. Shared environment belongs in .zshenv.
[[ -o interactive ]] || return

# Oh My Zsh stays intentionally small. setup.sh owns plugin installation.
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_THEME=""
plugins=(git zsh-autosuggestions fzf-tab)
# Compiled completion dumps are not portable across zsh versions.
ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
[[ -d "${ZSH_COMPDUMP:h}" ]] || mkdir -p "${ZSH_COMPDUMP:h}"

ZSH_AUTOSUGGEST_MANUAL_REBIND=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_HIGHLIGHT_MAXLENGTH=512

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  autoload -Uz compinit
  compinit
fi

# Machine-specific paths (for example Apache Ant or devspace tools) go here.
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# History
HISTFILE="$XDG_STATE_HOME/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"
HISTSIZE=10000
SAVEHIST=10000
setopt share_history hist_expire_dups_first hist_ignore_dups hist_verify

# Clipboard: pipe anything to `y` to copy via OSC 52 (SSH/tmux/mosh safe).
y() {
  local data encoded
  if [[ -t 0 ]]; then
    data="$*"
  else
    data=$(command cat)
  fi
  encoded=$(printf '%s' "$data" | base64 | tr -d '\n')
  printf '\e]52;c;%s\a' "$encoded" >/dev/tty
}

# Optional command aliases are only enabled when their tools are installed.
(( $+commands[bat] )) && alias cat='bat'
(( $+commands[eza] )) && alias ls='eza --icons=always -a'
alias gs='git status'
(( $+commands[lazygit] )) && alias lg='lazygit'
unalias download 2>/dev/null || true
if (( $+commands[aria2c] )); then
  download() {
    aria2c -x16 -s16 -- "$@"
  }
fi

# FZF tab completion
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
if (( $+commands[eza] )); then
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always -- $realpath'
else
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 -- $realpath'
fi
zstyle ':fzf-tab:*' switch-group '<' '>'

# Makefile target completion
_makefile_targets() {
  local -a targets
  targets=($(command make -qp 2>/dev/null | awk -F: '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ && !/^Makefile/ {split($1,A,/ /);for(i in A)print A[i]}' | sort -u))
  compadd "$@" -- $targets
}
if (( $+commands[make] && $+functions[compdef] )); then
  compdef _makefile_targets make
fi

# fnm is the sole Node version manager and owns its directory-change hook.
if (( $+commands[fnm] )); then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# Load conda/mamba only when first invoked.
_conda_init=""
if (( $+commands[conda] )); then
  _conda_init="${commands[conda]}"
else
  for _conda_root in "$HOME/mambaforge" "$HOME/miniforge3" "$HOME/miniconda3"; do
    if [[ -r "$_conda_root/etc/profile.d/conda.sh" ]]; then
      _conda_init="$_conda_root/etc/profile.d/conda.sh"
      break
    fi
  done
  unset _conda_root
fi

if [[ -n "$_conda_init" ]]; then
  _load_conda() {
    local hook
    unfunction conda mamba 2>/dev/null
    if [[ -x "$_conda_init" ]]; then
      hook="$("$_conda_init" shell.zsh hook 2>/dev/null)" || return
      [[ -n "$hook" ]] || return 1
      eval "$hook"
    else
      source "$_conda_init"
    fi
  }

  _run_conda_command() {
    local command_name="$1"
    shift
    _load_conda || {
      print -u2 "Unable to initialize conda/mamba."
      return 1
    }
    if whence "$command_name" >/dev/null; then
      "$command_name" "$@"
    else
      print -u2 "$command_name is not installed."
      return 127
    fi
  }

  conda() { _run_conda_command conda "$@" }
  mamba() { _run_conda_command mamba "$@" }
fi

# let `cd` fall back to zoxide when a direct path does not exist.
export _ZO_DOCTOR=0
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd cd)"
fi

# Atuin
if (( $+commands[atuin] )); then
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

# The canonical SSH workflow creates a tmux session whose future panes reconnect.
tmux-ssh() {
  if [[ -z ${1:-} ]]; then
    print -u2 "Usage: tmux-ssh user@host"
    return 1
  fi
  if (( ! $+commands[tmux] )); then
    print -u2 "tmux is not installed."
    return 127
  fi

  local target="$1"
  local session_name="ssh-${target//[^[:alnum:]_-]/-}"
  local ssh_command
  printf -v ssh_command 'exec ssh %q' "$target"

  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -d -s "$session_name" "$ssh_command" || return
    tmux set-option -t "$session_name" default-command "$ssh_command"
  fi

  if [[ -n ${TMUX:-} ]]; then
    tmux switch-client -t "$session_name"
  else
    tmux attach-session -t "$session_name"
  fi
}

# Starship owns the final prompt.
if (( $+commands[starship] )) && [[ ${TERM:-dumb} != dumb ]]; then
  eval "$(starship init zsh)"
fi

# Syntax highlighting must be sourced after every widget and keybinding.
_zsh_highlighting="${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[[ -r "$_zsh_highlighting" ]] && source "$_zsh_highlighting"
unset _zsh_highlighting

# pnpm
export PNPM_HOME="/Users/dbhowal/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
