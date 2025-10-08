#!/usr/bin/env bash
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1; }
say()  { printf "\033[1;34m==>\033[0m %s\n" "$*"; }

os() {
  case "$(uname -s)" in
    Darwin) echo mac ;;
    Linux)
      if [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
        echo ubuntu
      else
        echo linux
      fi
      ;;
    *) echo other ;;
  esac
}

ensure_base() {
  case "$(os)" in
    mac)
      if ! need brew; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      brew update
      brew install git stow vim tmux curl zsh node npm ripgrep fd fzf
      brew tap homebrew/cask-fonts || true
      brew install --cask wezterm || true
      ;;
    ubuntu)
      sudo apt-get update
      sudo apt-get install -y git stow vim tmux curl zsh nodejs npm ripgrep fd-find fzf
      if need fdfind && ! need fd; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
      fi
      ;;
    *)
      say "Unknown platform. Install git stow vim tmux curl zsh node npm manually."
      ;;
  esac
}

ensure_fonts() {
  case "$(os)" in
    mac)
      if ! brew list --cask | grep -q "^font-meslo-lg-nerd-font$"; then
        brew install --cask font-meslo-lg-nerd-font
      fi
      ;;
    *)
      mkdir -p "$HOME/.local/share/fonts"
      cd "$HOME/.local/share/fonts"
      if ! ls *Meslo*NF*.ttf >/dev/null 2>&1; then
        curl -fsSLO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Meslo.zip
        unzip -o Meslo.zip >/dev/null && rm -f Meslo.zip
        fc-cache -f >/dev/null 2>&1 || true
      fi
      ;;
  esac
}

ensure_vimplug() {
  local plug="$HOME/.vim/autoload/plug.vim"
  if [ ! -f "$plug" ]; then
    say "Installing vim plug"
    curl -fLo "$plug" --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  fi
}

ensure_tpm() {
  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    say "Installing tmux plugin manager"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  fi
}

ensure_p10k() {
  if [ ! -d "$HOME/.powerlevel10k" ]; then
    say "Installing powerlevel10k"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.powerlevel10k"
  fi
  if [ ! -f "$HOME/.p10k.zsh" ]; then
    cp "$HOME/.powerlevel10k/config/p10k-lean.zsh" "$HOME/.p10k.zsh" 2>/dev/null || true
  fi
}

layout_dotfiles_repo() {
  say "Laying out dotfiles repo"
  mkdir -p "$HOME/dotfiles"/{vim,zsh,wezterm,tmux}

  [ -f "./.vimrc" ]      && install -m0644 "./.vimrc"      "$HOME/dotfiles/vim/.vimrc"      || { [ -f "$HOME/.vimrc" ]      && install -m0644 "$HOME/.vimrc"      "$HOME/dotfiles/vim/.vimrc"; }
  [ -f "./.zshrc" ]      && install -m0644 "./.zshrc"      "$HOME/dotfiles/zsh/.zshrc"      || { [ -f "$HOME/.zshrc" ]      && install -m0644 "$HOME/.zshrc"      "$HOME/dotfiles/zsh/.zshrc"; }
  [ -f "./.wezterm.lua" ]&& install -m0644 "./.wezterm.lua"$HOME/dotfiles/wezterm/.wezterm.lua" || { [ -f "$HOME/.wezterm.lua" ]&& install -m0644 "$HOME/.wezterm.lua" "$HOME/dotfiles/wezterm/.wezterm.lua"; }
  [ -f "./.tmux.conf" ]  && install -m0644 "./.tmux.conf"  "$HOME/dotfiles/tmux/.tmux.conf"  || { [ -f "$HOME/.tmux.conf" ]  && install -m0644 "$HOME/.tmux.conf"  "$HOME/dotfiles/tmux/.tmux.conf"; }

  cd "$HOME/dotfiles"
  if [ ! -d .git ]; then
    git init
    git add .
    git commit -m "bootstrap dotfiles" >/dev/null 2>&1 || true
  fi
}

stow_all() {
  say "Symlinking with Stow"
  cd "$HOME/dotfiles"
  stow -t "$HOME" vim zsh wezterm tmux || true
}

vim_headless() {
  say "Installing Vim plugins headless"
  vim +PlugInstall +qall || true
  # Coc extensions are optional. Install only if Coc is declared.
  if grep -q "coc.nvim" "$HOME/dotfiles/vim/.vimrc" 2>/dev/null; then
    vim +'CocInstall -sync coc-pyright coc-rust-analyzer coc-java' +qall || true
  fi
}

tmux_headless() {
  say "Installing tmux plugins headless"
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
}

main() {
  say "Ensuring base tools"
  ensure_base
  say "Ensuring fonts"
  ensure_fonts
  say "Ensuring managers"
  ensure_vimplug
  ensure_tpm
  ensure_p10k
  layout_dotfiles_repo
  stow_all
  vim_headless
  tmux_headless
  say "Done"
}

main "$@"
