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

# micromamba is resolved from PATH and its root prefix comes from .zshenv, so no
# install location is baked in here. The shell hook costs a subprocess, so it is
# deferred until the first micromamba/mamba call rather than run at every prompt.
if (( $+commands[micromamba] )); then
  # The stubs must be functions, not aliases: the hook body contains a `mamba() {`
  # branch that zsh parses even when unreachable, and an alias of that name makes
  # the whole eval a parse error.
  _load_micromamba() {
    unfunction micromamba mamba 2>/dev/null
    eval "$(command micromamba shell hook --shell zsh)" || {
      print -u2 "micromamba shell hook failed."
      return 1
    }
    # the hook defines only the function matching its own basename
    mamba() { micromamba "$@" }
  }

  micromamba() { _load_micromamba && micromamba "$@" }
  mamba() { _load_micromamba && micromamba "$@" }
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

# Unity CLI
. "/Users/druhi/.unity/env"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/druhi/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/druhi/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/druhi/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/druhi/google-cloud-sdk/completion.zsh.inc'; fi
