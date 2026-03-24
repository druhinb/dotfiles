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

    -- Automatically align remote Neovim versions with local version (e.g. v0.12.2)
    local config_dir = vim.fn.stdpath("data") .. "/remote-nvim.nvim"
    local config_file = config_dir .. "/workspace.json"
    local local_version = "v" .. vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch
    local f = io.open(config_file, "r")
    if f then
      local content = f:read("*a")
      f:close()
      local ok, data = pcall(vim.json.decode, content)
      if ok and type(data) == "table" then
        local changed = false
        for _, cfg in pairs(data) do
          if cfg.neovim_version ~= local_version then
            cfg.neovim_version = local_version
            changed = true
          end
        end
        if changed then
          local out = io.open(config_file, "w")
          if out then
            out:write(vim.json.encode(data))
            out:close()
          end
        end
      end
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
            # 3. Portable Tree-Sitter CLI Installation (No sudo required, for Treesitter parser compilation)
            if ! command -v tree-sitter &>/dev/null && [ ! -f "$HOME/.local/bin/tree-sitter" ]; then
              # Pin a version compatible with GLIBC 2.35 (e.g. v0.25.2)
              TARGET_TAG="v0.25.2"
              
              TMP_DIR=$(mktemp -d)
              CD_DIR=$(pwd)
              cd "$TMP_DIR"
              
              curl -sLO "https://github.com/tree-sitter/tree-sitter/releases/download/${TARGET_TAG}/tree-sitter-linux-x64.gz"
              gunzip -f tree-sitter-linux-x64.gz
              mv tree-sitter-linux-x64 "$HOME/.local/bin/tree-sitter"
              chmod +x "$HOME/.local/bin/tree-sitter"
              
              cd "$CD_DIR"
              rm -rf "$TMP_DIR"
            fi
          ]]

          -- Execute the script via the remote-nvim provider abstraction layer
          backend:run_command(client_id, portable_installer)
        end,
      },
    }
  end,
}
