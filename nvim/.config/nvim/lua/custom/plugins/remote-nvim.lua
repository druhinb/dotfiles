return {
  'amitds1997/remote-nvim.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    -- Inject remote paths locally so Neovim can locate the binaries immediately upon launch
    local home = os.getenv 'HOME'
    if home then
      vim.env.PATH = home .. '/.local/bin:' .. home .. '/.fzf/bin:' .. vim.env.PATH
    end

    require('remote-nvim').setup {
      -- offline_mode = false, -- Ensure downloading is permitted
      remote = {
        app_list = {
          neovim = {
            -- Ensures remote Neovim instance also receives the path updates
            env = {
              PATH = '$HOME/.local/bin:$HOME/.fzf/bin:$PATH',
            },
          },
        },
      },
      hooks = {
        ---@param backend remote-nvim.providers.Provider
        ---@param client_id string
        after_connect = function(backend, client_id)
          -- Non-interactive static binary installation script for Linux x86_64
          local portable_installer = [[
            mkdir -p "$HOME/.local/bin"

            # 1. Portable FZF Installation (No sudo required)
            if ! command -v fzf &> /dev/null && [ ! -f "$HOME/.local/bin/fzf" ]; then
              if [ ! -d "$HOME/.fzf" ]; then
                git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
              fi
              "$HOME/.fzf/install" --bin --no-bash --no-zsh --no-fish
              ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
            fi

            # 2. Portable Yazi Installation (Prebuilt static musl binary)
            if ! command -v yazi &> /dev/null && [ ! -f "$HOME/.local/bin/yazi" ]; then
              # Fetch latest release tag via GitHub API
              LATEST_TAG=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
              
              if [ -n "$LATEST_TAG" ]; then
                TMP_DIR=$(mktemp -d)
                CD_DIR=$(pwd)
                cd "$TMP_DIR"
                
                curl -sLO "https://github.com/sxyazi/yazi/releases/download/${LATEST_TAG}/yazi-x86_64-unknown-linux-musl.zip"
                
                # Unzip fallback if unzip utility is missing
                if command -v unzip &> /dev/null; then
                  unzip -q yazi-x86_64-unknown-linux-musl.zip
                else
                  python3 -m zipfile -e yazi-x86_64-unknown-linux-musl.zip .
                fi
                
                mv yazi-x86_64-unknown-linux-musl/yazi "$HOME/.local/bin/"
                mv yazi-x86_64-unknown-linux-musl/ya "$HOME/.local/bin/"
                
                cd "$CD_DIR"
                rm -rf "$TMP_DIR"
              fi
            fi
          ]]

          -- Execute the script via the remote-nvim provider abstraction layer
          backend:run_command(client_id, portable_installer)
        end,
      },
    }
  end,
}
