# Login-shell environment. Keep interactive shell behavior in .zshrc.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"

typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$CARGO_HOME/bin"
  "$HOME/.local/share/nvim/mason/bin"
  "$HOME/bin"
  "$HOME/.nix-profile/bin"
  /nix/var/nix/profiles/default/bin
  $path
)
export PATH

if [[ -x /usr/bin/zsh ]]; then
  export SHELL=/usr/bin/zsh
fi
