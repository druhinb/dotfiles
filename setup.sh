#!/usr/bin/env bash

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles-backup-$(date +%Y%m%d%H%M%S)}"
DRY_RUN=0
LINK_ONLY=0
SKIP_NEOVIM_TOOLS=0
OS_NAME="${OS_NAME:-$(uname -s)}"
BREW_MANAGES_RUST_TOOLS=0

usage() {
	cat <<'USAGE'
Usage: ./setup.sh [--dry-run] [--link-only] [--skip-neovim-tools]

Installs tools used by this dotfiles repo on Linux or macOS, links configs
into place, installs shell/tmux/Vim/Neovim plugins, and switches the default
shell to zsh. macOS setup assumes Homebrew is already installed.

Options:
  --dry-run            Print actions without changing files.
  --link-only          Create or refresh configuration symlinks only.
  --skip-neovim-tools  Skip Mason LSP/formatter/debugger installation.
USAGE
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run)
		DRY_RUN=1
		;;
	--link-only)
		LINK_ONLY=1
		;;
	--skip-neovim-tools)
		SKIP_NEOVIM_TOOLS=1
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
	shift
done

log() {
	printf '\n==> %s\n' "$*"
}

warn() {
	printf 'WARN: %s\n' "$*" >&2
}

run() {
	if [[ "$DRY_RUN" == 1 ]]; then
		printf '+'
		printf ' %q' "$@"
		printf '\n'
	else
		"$@"
	fi
}

have() {
	command -v "$1" >/dev/null 2>&1
}

prepend_path_if_exists() {
	local dir="$1"

	[[ -d "$dir" ]] || return

	case ":$PATH:" in
	*":$dir:"*) ;;
	*) export PATH="$dir:$PATH" ;;
	esac
}

setup_homebrew_path() {
	prepend_path_if_exists /usr/local/bin
	prepend_path_if_exists /opt/homebrew/bin
}

sudo_run() {
	if [[ "$(id -u)" == 0 ]]; then
		run "$@"
	else
		run sudo "$@"
	fi
}

install_apt_packages() {
	if ! have apt-get; then
		warn "apt-get not found; skipping distro package installation."
		return
	fi

	log "Installing distro packages"
	sudo_run apt-get update
	sudo_run apt-get install -y \
		zsh tmux vim fzf ripgrep fd-find bat zoxide \
		git curl wget unzip build-essential cmake jq shellcheck

	# Package names and availability vary across supported Linux releases.
	# Keep these conveniences best-effort instead of blocking the bootstrap.
	local package
	for package in eza lazygit shfmt; do
		have "$package" || sudo_run apt-get install -y "$package" || warn "apt-get install $package failed; continuing."
	done
}

install_brew_packages() {
	setup_homebrew_path

	if ! have brew; then
		warn "brew not found; skipping Homebrew package installation."
		return
	fi

	BREW_MANAGES_RUST_TOOLS=1

	log "Installing Homebrew packages"
	run brew update

	local packages=(
		zsh
		tmux
		vim
		neovim
		fzf
		ripgrep
		fd
		bat
		eza
		zoxide
		fnm
		jq
		lazygit
		shfmt
		shellcheck
		stylua
		git
		curl
		wget
		unzip
		cmake
		starship
		atuin
		yazi
	)

	local package
	for package in "${packages[@]}"; do
		if brew list --formula "$package" >/dev/null 2>&1; then
			continue
		fi

		run brew install "$package" || warn "brew install $package failed; continuing."
	done
}

install_system_packages() {
	case "$OS_NAME" in
	Darwin)
		install_brew_packages
		;;
	Linux)
		install_apt_packages
		;;
	*)
		warn "Unsupported OS '$OS_NAME'; skipping system package installation."
		;;
	esac
}

install_rust_tools() {
	if [[ "$BREW_MANAGES_RUST_TOOLS" == 1 ]]; then
		return
	fi

	if have fnm && have starship && have atuin && have yazi && have ya && have stylua; then
		return
	fi

	if ! have cargo; then
		warn "cargo not found; skipping Rust tool installation."
		return
	fi

	log "Installing Rust tools"
	have fnm || run cargo install fnm --locked
	have starship || run cargo install starship --locked
	have atuin || run cargo install atuin --locked
	have stylua || run cargo install stylua --locked

	if have yazi && have ya; then
		return
	fi

	# Yazi's crates.io packaging currently requires yazi-build, and in this
	# devspace yazi-fm may still fail if the internal crate mirror is missing
	# bundled preset Lua files. Keep this best-effort so the rest of setup works.
	have yazi-build || run cargo install --force yazi-build --locked
	have ya || run cargo install --force yazi-cli --locked
	if ! have yazi; then
		run cargo install --force yazi-fm --locked || warn "yazi-fm failed to install; continuing without the yazi binary."
	fi
}

link_file() {
	local source="$1"
	local target="$2"
	local backup_target backup_index

	if [[ ! -e "$source" && ! -L "$source" ]]; then
		warn "Missing source: $source"
		return
	fi

	if [[ -L "$target" && "$(command -p readlink "$target")" == "$source" ]]; then
		return
	fi

	if [[ -e "$target" || -L "$target" ]]; then
		run mkdir -p "$BACKUP_DIR"
		backup_target="$BACKUP_DIR/$(basename "$target")"
		backup_index=1
		while [[ -e "$backup_target" || -L "$backup_target" ]]; do
			backup_target="$BACKUP_DIR/$(basename "$target").$backup_index"
			((backup_index++))
		done

		if ! run mv "$target" "$backup_target"; then
			warn "Could not back up $target; leaving it unchanged."
			return 1
		fi
	fi

	run mkdir -p "$(dirname "$target")"
	run ln -s "$source" "$target"
}

link_dotfiles() {
	log "Linking dotfiles"
	run "$DOTFILES_DIR/sync-agents.sh"
	link_file "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"
	link_file "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.zprofile"
	link_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
	link_file "$DOTFILES_DIR/vim/.vimrc" "$HOME/.vimrc"
	link_file "$DOTFILES_DIR/ideavimrc/.ideavimrc" "$HOME/.ideavimrc"
	link_file "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
	link_file "$DOTFILES_DIR/nvim/.config/nvim" "$HOME/.config/nvim"
	link_file "$DOTFILES_DIR/starship/.config/starship.toml" "$HOME/.config/starship.toml"
	link_file "$DOTFILES_DIR/atuin/.config/atuin" "$HOME/.config/atuin"
	link_file "$DOTFILES_DIR/karabiner/.config/karabiner" "$HOME/.config/karabiner"
	link_file "$DOTFILES_DIR/wezterm/.wezterm.lua" "$HOME/.wezterm.lua"
	link_file "$DOTFILES_DIR/herdr/.config/herdr/config.toml" "$HOME/.config/herdr/config.toml"
	link_file "$DOTFILES_DIR/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
	link_file "$DOTFILES_DIR/.claude/settings.json" "$HOME/.claude/settings.json"
	link_file "$DOTFILES_DIR/.claude/keybindings.json" "$HOME/.claude/keybindings.json"
	link_file "$DOTFILES_DIR/.claude/statusline.sh" "$HOME/.claude/statusline.sh"
	link_file "$DOTFILES_DIR/.claude/subagent-statusline.sh" "$HOME/.claude/subagent-statusline.sh"
	local hook_file
	for hook_file in "$DOTFILES_DIR"/.claude/hooks/*.sh; do
		[[ -e "$hook_file" ]] || continue
		link_file "$hook_file" "$HOME/.claude/hooks/$(basename "$hook_file")"
	done
	local agent_file
	for agent_file in "$DOTFILES_DIR"/.claude/agents/*.md; do
		[[ -e "$agent_file" ]] || continue
		link_file "$agent_file" "$HOME/.claude/agents/$(basename "$agent_file")"
	done
	for agent_file in "$DOTFILES_DIR"/.claude/commands/*.md; do
		[[ -e "$agent_file" ]] || continue
		link_file "$agent_file" "$HOME/.claude/commands/$(basename "$agent_file")"
	done
	link_file "$DOTFILES_DIR/codex/.codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
	for agent_file in "$DOTFILES_DIR"/codex/.codex/agents/*.toml; do
		[[ -e "$agent_file" ]] || continue
		link_file "$agent_file" "$HOME/.codex/agents/$(basename "$agent_file")"
	done

	link_file "$DOTFILES_DIR/opencode/.config/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
	link_file "$DOTFILES_DIR/opencode/.config/opencode/tui.json" "$HOME/.config/opencode/tui.json"
	for agent_file in "$DOTFILES_DIR"/opencode/.config/opencode/agents/*.md; do
		[[ -e "$agent_file" ]] || continue
		link_file "$agent_file" "$HOME/.config/opencode/agents/$(basename "$agent_file")"
	done
	for agent_file in "$DOTFILES_DIR"/opencode/.config/opencode/commands/*.md; do
		[[ -e "$agent_file" ]] || continue
		link_file "$agent_file" "$HOME/.config/opencode/commands/$(basename "$agent_file")"
	done

	# One versioned skill source serves all three agent clients. Link entries
	# individually so Codex's bundled .system directory remains untouched.
	local skill skill_name
	for skill in "$DOTFILES_DIR"/agents/skills/*; do
		[[ -d "$skill" ]] || continue
		skill_name="$(basename "$skill")"
		link_file "$skill" "$HOME/.claude/skills/$skill_name"
		link_file "$skill" "$HOME/.codex/skills/$skill_name"
		link_file "$skill" "$HOME/.config/opencode/skills/$skill_name"
	done

	# Ubuntu names these binaries differently than the aliases in .zshrc expect.
	have bat || { [[ -x /usr/bin/batcat ]] && link_file /usr/bin/batcat "$HOME/.local/bin/bat"; }
	have fd || { [[ -x /usr/bin/fdfind ]] && link_file /usr/bin/fdfind "$HOME/.local/bin/fd"; }
}

clone_if_missing() {
	local url="$1"
	local dest="$2"

	if [[ -d "$dest/.git" ]]; then
		return
	fi

	run rm -rf "$dest"
	run git clone --depth=1 "$url" "$dest"
}

install_zsh_plugins() {
	local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
	log "Installing zsh plugins"

	if [[ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
		run rm -rf "$HOME/.oh-my-zsh"
		clone_if_missing https://github.com/ohmyzsh/ohmyzsh "$HOME/.oh-my-zsh"
	fi

	run mkdir -p "$plugin_dir"
	clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions"
	clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir/zsh-syntax-highlighting"
	clone_if_missing https://github.com/Aloxaf/fzf-tab "$plugin_dir/fzf-tab"
}

install_tmux_plugins() {
	log "Installing tmux plugins"

	# Older revisions linked the repository's plugin gitlinks into ~/.tmux.
	# Migrate that link once, then let TPM exclusively own the plugin directory.
	if [[ -L "$HOME/.tmux" && "$(command -p readlink "$HOME/.tmux")" == "$DOTFILES_DIR/tmux/.tmux" ]]; then
		run rm "$HOME/.tmux"
	fi
	run mkdir -p "$HOME/.tmux/plugins"

	clone_if_missing https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"

	if have tmux && [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
		run tmux start-server \; set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.tmux/plugins/" \; source-file "$HOME/.tmux.conf"
		run bash "$HOME/.tmux/plugins/tpm/bin/install_plugins"
	else
		warn "tmux or TPM install script not found; skipping tmux plugin install."
	fi
}

install_vim_plugins() {
	log "Installing Vim plugins"
	run mkdir -p "$HOME/.vim/autoload" "$HOME/.local/share"
	clone_if_missing https://github.com/junegunn/vim-plug "$HOME/.local/share/vim-plug"
	link_file "$HOME/.local/share/vim-plug/plug.vim" "$HOME/.vim/autoload/plug.vim"

	if have vim; then
		run vim -Nu "$HOME/.vimrc" -n -es "+PlugInstall --sync" +qa || warn "Vim PlugInstall returned nonzero; continuing."
	fi
}

install_neovim_plugins() {
	if ! have nvim; then
		warn "nvim not found; skipping Neovim setup."
		return
	fi

	log "Installing Neovim plugins"
	run nvim --headless "+Lazy! sync" +qa || warn "Neovim plugin sync returned nonzero; run :Lazy sync inside Neovim for details."

	if [[ "$SKIP_NEOVIM_TOOLS" == 1 ]]; then
		warn "Skipping Mason tool installation by request."
		return
	fi

	log "Installing Neovim Mason tools"
	run nvim --headless \
		"+lua require('lazy').load { plugins = { 'mason-tool-installer.nvim' } }" \
		"+MasonToolsInstallSync" \
		"+lua local t=require('tooling'); local missing={}; for _,p in ipairs(t.mason_packages()) do if not t.mason_package_installed(p) then table.insert(missing,p) end end; if #missing>0 then print('Missing Mason packages: '..table.concat(missing,',')); vim.cmd.cquit() end" \
		+qa || warn "Mason tool installation returned nonzero; run :Mason inside Neovim for details."

	log "Installing Neovim Tree-sitter parsers"
	run nvim --headless \
		"+ToolingInstallTreesitter" \
		"+lua if vim.g.tooling_treesitter_install_ok ~= true then vim.cmd.cquit() end" \
		+qa || warn "Tree-sitter parser installation returned nonzero; run :ToolingInstallTreesitter inside Neovim for details."
}

current_login_shell() {
	local login_shell

	if [[ "$OS_NAME" == "Darwin" ]] && have dscl; then
		login_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
		if [[ -n "$login_shell" ]]; then
			printf '%s\n' "$login_shell"
			return
		fi
	fi

	if have getent; then
		login_shell="$(getent passwd "$USER" | cut -d: -f7)"
		if [[ -n "$login_shell" ]]; then
			printf '%s\n' "$login_shell"
			return
		fi
	fi

	printf '%s\n' "${SHELL:-}"
}

ensure_shell_is_listed() {
	local shell_path="$1"

	[[ -f /etc/shells ]] || return
	grep -Fxq "$shell_path" /etc/shells && return

	log "Adding $shell_path to /etc/shells"
	if [[ "$DRY_RUN" == 1 ]]; then
		printf "+ printf '%%s\\n' %q | sudo tee -a /etc/shells >/dev/null\n" "$shell_path"
	elif [[ "$(id -u)" == 0 ]]; then
		printf '%s\n' "$shell_path" >>/etc/shells
	else
		printf '%s\n' "$shell_path" | sudo tee -a /etc/shells >/dev/null
	fi
}

set_default_shell() {
	if ! have zsh; then
		warn "zsh not found; cannot change default shell."
		return
	fi

	local zsh_path current_shell
	zsh_path="$(command -v zsh)"
	current_shell="$(current_login_shell)"

	if [[ "$current_shell" == "$zsh_path" ]]; then
		return
	fi

	ensure_shell_is_listed "$zsh_path"

	log "Changing default shell to $zsh_path"
	if [[ "$OS_NAME" == "Darwin" ]]; then
		run chsh -s "$zsh_path"
	else
		sudo_run chsh -s "$zsh_path" "$USER"
	fi
}

smoke_test() {
	log "Running smoke tests"
	have zsh && run zsh -ic "echo ZSH_OK"
	have tmux && run bash -lc "tmux -f '$HOME/.tmux.conf' new-session -d -s dotfiles-smoke 'echo TMUX_OK; sleep 1' && tmux kill-session -t dotfiles-smoke"
	have vim && run vim -Nu "$HOME/.vimrc" -n -es "+qa"
	have nvim && run nvim --headless "+qa"
}

main() {
	if [[ "$LINK_ONLY" == 1 ]]; then
		link_dotfiles

		log "Done"
		if [[ -d "$BACKUP_DIR" ]]; then
			echo "Backups: $BACKUP_DIR"
		fi
		return
	fi

	install_system_packages
	install_rust_tools
	link_dotfiles
	install_zsh_plugins
	install_tmux_plugins
	install_vim_plugins
	install_neovim_plugins
	set_default_shell
	smoke_test

	log "Done"
	if [[ -d "$BACKUP_DIR" ]]; then
		echo "Backups: $BACKUP_DIR"
	fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
