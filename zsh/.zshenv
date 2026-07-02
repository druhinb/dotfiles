# Environment shared by login, interactive, and tmux-launched zsh processes.
# Keep this file command-free so non-interactive shells stay predictable.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"

typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$CARGO_HOME/bin"
  "$XDG_DATA_HOME/nvim/mason/bin"
  "$HOME/bin"
  $path
)

# Homebrew uses different prefixes on Apple Silicon and Intel Macs.
if [[ -z ${HOMEBREW_PREFIX:-} ]]; then
  if [[ -d /opt/homebrew ]]; then
    export HOMEBREW_PREFIX=/opt/homebrew
  elif [[ -d /usr/local/Homebrew ]]; then
    export HOMEBREW_PREFIX=/usr/local
  fi
fi

if [[ -n ${HOMEBREW_PREFIX:-} ]]; then
  export HOMEBREW_CELLAR="${HOMEBREW_CELLAR:-$HOMEBREW_PREFIX/Cellar}"
  if [[ -z ${HOMEBREW_REPOSITORY:-} ]]; then
    if [[ "$HOMEBREW_PREFIX" == /usr/local && -d /usr/local/Homebrew ]]; then
      export HOMEBREW_REPOSITORY=/usr/local/Homebrew
    else
      export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX"
    fi
  fi

  path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" $path)
  case ":${MANPATH:-}:" in
    *":$HOMEBREW_PREFIX/share/man:"*) ;;
    *) export MANPATH="$HOMEBREW_PREFIX/share/man:${MANPATH:-}" ;;
  esac
  case ":${INFOPATH:-}:" in
    *":$HOMEBREW_PREFIX/share/info:"*) ;;
    *) export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}" ;;
  esac
fi

[[ -d "$HOME/.nix-profile/bin" ]] && path=("$HOME/.nix-profile/bin" $path)
[[ -d /nix/var/nix/profiles/default/bin ]] && path=(/nix/var/nix/profiles/default/bin $path)

export PATH
