#===== Instant prompt (Powerlevel10k) =====
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ===== History =====
export HISTFILE=${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history
mkdir -p "$(dirname "$HISTFILE")"
export HISTSIZE=200000
export SAVEHIST=200000
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_VERIFY SHARE_HISTORY INC_APPEND_HISTORY_TIME

# ===== Safer defaults =====
setopt NO_CLOBBER EXTENDED_GLOB INTERACTIVE_COMMENTS
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt COMPLETE_IN_WORD
bindkey -e

# ===== Completion =====
autoload -Uz compinit bashcompinit
_compdump=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compdump
mkdir -p "${_compdump%/*}"
compinit -d "$_compdump"
bashcompinit

# ===== Conda / Mamba =====
for _conda in "$HOME/mambaforge" "$HOME/miniforge3" "$HOME/miniconda3" "/opt/homebrew/Caskroom/mambaforge/base"; do
  if [ -r "$_conda/etc/profile.d/conda.sh" ]; then
    . "$_conda/etc/profile.d/conda.sh"
    conda config --set auto_activate_base false >/dev/null 2>&1
    break
  fi
done
unset _conda

# ===== Powerlevel10k =====
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ===== Aliases =====
alias ll='ls -lh'
alias la='ls -lha'
alias grep='grep --color=auto'
eval "$(thefuck --alias fk)"

# ===== NVM (lazy load) =====
export NVM_DIR="$HOME/.nvm"
if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
  _nvm_load() { unset -f node npm npx nvm; . "/opt/homebrew/opt/nvm/nvm.sh"; command "$@" ; }
  node() { _nvm_load node "$@"; }
  npm()  { _nvm_load npm  "$@"; }
  npx()  { _nvm_load npx  "$@"; }
  nvm()  { _nvm_load nvm  "$@"; }
fi

# ===== Zoxide =====
# Zoxide integration
eval "$(zoxide init zsh)"

# Ensure no alias conflicts
unalias cd 2>/dev/null || true

z() { __zoxide_z "$@"; }
cd() {
  if [ $# -gt 0 ]; then
    builtin cd "$@"
  else
    builtin cd ~
  fi
}

# ===== fzf integration =====
export FZF_DEFAULT_COMMAND='fd --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
if command -v bat >/dev/null 2>&1; then
  export FZF_CTRL_T_OPTS='--preview "bat --style=numbers --color=always --line-range :200 {}"'
fi

# ===== Autosuggestions & Syntax Highlighting =====
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

# ===== Environment =====
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
if command -v bat >/dev/null 2>&1; then
  export PAGER=bat
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# ===== Local overrides =====
[ -f ~/.zshrc.local ] && source ~/.zshrc.localxport PATH="$ANT_HOME/bin:$PATH"
