-- ============================================================================
-- FZF-Lua - Fuzzy Finder (LazyVim Style, Optimized for Speed)
-- Ultra-fast fuzzy finding with native fzf
-- ============================================================================
return {
  {
    'ibhagwan/fzf-lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    cmd = 'FzfLua',
    -- stylua: ignore
    keys = {
      -- ════════════════════════════════════════════════════════════════════
      -- File/Find (leader-f and leader-s for search)
      -- ════════════════════════════════════════════════════════════════════
      { '<leader><space>', function() require('fzf-lua').files() end, desc = 'Find Files (Root)' },
      { '<leader>ff', function() require('fzf-lua').files() end, desc = 'Find Files (Root)' },
      { '<leader>fF', function() require('fzf-lua').files({ cwd = vim.fn.expand('%:p:h') }) end, desc = 'Find Files (cwd)' },
      { '<leader>fr', function() require('fzf-lua').oldfiles() end, desc = 'Recent Files' },
      { '<leader>fR', function() require('fzf-lua').oldfiles({ cwd = vim.loop.cwd() }) end, desc = 'Recent Files (cwd)' },
      { '<leader>fb', function() require('fzf-lua').buffers() end, desc = 'Buffers' },
      { '<leader>fg', function() require('fzf-lua').git_files() end, desc = 'Git Files' },
      -- ════════════════════════════════════════════════════════════════════
      -- Search (leader-s)
      -- ════════════════════════════════════════════════════════════════════
      { '<leader>sg', function() require('fzf-lua').live_grep() end, desc = 'Grep (Root)' },
      { '<leader>sG', function() require('fzf-lua').live_grep({ cwd = vim.fn.expand('%:p:h') }) end, desc = 'Grep (cwd)' },
      { '<leader>sw', function() require('fzf-lua').grep_cword() end, desc = 'Word (Root)' },
      { '<leader>sW', function() require('fzf-lua').grep_cword({ cwd = vim.fn.expand('%:p:h') }) end, desc = 'Word (cwd)' },
      { '<leader>sw', function() require('fzf-lua').grep_visual() end, mode = 'v', desc = 'Selection (Root)' },
      { '<leader>sW', function() require('fzf-lua').grep_visual({ cwd = vim.fn.expand('%:p:h') }) end, mode = 'v', desc = 'Selection (cwd)' },
      { '<leader>sb', function() require('fzf-lua').lgrep_curbuf() end, desc = 'Buffer Lines' },
      { '<leader>/', function() require('fzf-lua').lgrep_curbuf() end, desc = 'Search in Buffer' },
      { '<leader>ss', function() require('fzf-lua').builtin() end, desc = 'FzfLua Builtins' },
      { '<leader>sr', function() require('fzf-lua').resume() end, desc = 'Resume' },
      { '<leader>s"', function() require('fzf-lua').registers() end, desc = 'Registers' },
      { '<leader>sa', function() require('fzf-lua').autocmds() end, desc = 'Autocmds' },
      { '<leader>sc', function() require('fzf-lua').command_history() end, desc = 'Command History' },
      { '<leader>sC', function() require('fzf-lua').commands() end, desc = 'Commands' },
      { '<leader>sd', function() require('fzf-lua').diagnostics_document() end, desc = 'Document Diagnostics' },
      { '<leader>sD', function() require('fzf-lua').diagnostics_workspace() end, desc = 'Workspace Diagnostics' },
      { '<leader>sh', function() require('fzf-lua').help_tags() end, desc = 'Help Pages' },
      { '<leader>sH', function() require('fzf-lua').highlights() end, desc = 'Highlight Groups' },
      { '<leader>sj', function() require('fzf-lua').jumps() end, desc = 'Jumplist' },
      { '<leader>sk', function() require('fzf-lua').keymaps() end, desc = 'Keymaps' },
      { '<leader>sl', function() require('fzf-lua').loclist() end, desc = 'Location List' },
      { '<leader>sm', function() require('fzf-lua').marks() end, desc = 'Marks' },
      { '<leader>sM', function() require('fzf-lua').manpages() end, desc = 'Man Pages' },
      { '<leader>so', function() require('fzf-lua').vim_options() end, desc = 'Options' },
      { '<leader>sq', function() require('fzf-lua').quickfix() end, desc = 'Quickfix List' },
      { '<leader>st', function() require('fzf-lua').colorschemes() end, desc = 'Colorschemes' },
      -- ════════════════════════════════════════════════════════════════════
      -- Git (leader-g)
      -- ════════════════════════════════════════════════════════════════════
      { '<leader>gfc', function() require('fzf-lua').git_commits() end, desc = 'Find Git Commits' },
      { '<leader>gfC', function() require('fzf-lua').git_bcommits() end, desc = 'Find Git Buffer Commits' },
      { '<leader>gfS', function() require('fzf-lua').git_stash() end, desc = 'Find Git Stash' },
    },
    opts = function()
      local fzf = require 'fzf-lua'
      local actions = fzf.actions

      -- Return configuration
      return {
        -- Use fzf-native for maximum performance
        'fzf-native',
        -- Global options
        global_resume = true,
        global_resume_query = true,
        -- Winopts for floating window
        winopts = {
          height = 0.85,
          width = 0.80,
          row = 0.35,
          col = 0.50,
          border = 'rounded',
          preview = {
            default = 'builtin',
            border = 'border',
            wrap = 'nowrap',
            hidden = 'nohidden',
            vertical = 'down:45%',
            horizontal = 'right:50%',
            layout = 'flex',
            flip_columns = 120,
            title = true,
            title_pos = 'center',
            scrollbar = 'float',
            scrolloff = '-2',
            scrollchars = { '█', '' },
            delay = 100,
            winopts = {
              number = true,
              relativenumber = false,
              cursorline = true,
              cursorlineopt = 'both',
              cursorcolumn = false,
              signcolumn = 'no',
              list = false,
              foldenable = false,
              foldmethod = 'manual',
            },
          },
          on_create = function()
            vim.keymap.set('t', '<C-j>', '<Down>', { silent = true, buffer = true })
            vim.keymap.set('t', '<C-k>', '<Up>', { silent = true, buffer = true })
          end,
        },
        -- Key bindings
        keymap = {
          builtin = {
            ['<F1>'] = 'toggle-help',
            ['<F2>'] = 'toggle-fullscreen',
            ['<F3>'] = 'toggle-preview-wrap',
            ['<F4>'] = 'toggle-preview',
            ['<F5>'] = 'toggle-preview-ccw',
            ['<F6>'] = 'toggle-preview-cw',
            ['<C-d>'] = 'preview-page-down',
            ['<C-u>'] = 'preview-page-up',
          },
          fzf = {
            ['ctrl-z'] = 'abort',
            ['ctrl-a'] = 'toggle-all',
            ['ctrl-q'] = 'select-all+accept',
            ['ctrl-d'] = 'preview-page-down',
            ['ctrl-u'] = 'preview-page-up',
          },
        },
        -- Actions
        actions = {
          files = {
            ['default'] = actions.file_edit_or_qf,
            ['ctrl-s'] = actions.file_split,
            ['ctrl-v'] = actions.file_vsplit,
            ['ctrl-t'] = actions.file_tabedit,
            ['ctrl-q'] = actions.file_sel_to_qf,
            ['alt-q'] = actions.file_sel_to_ll,
          },
          buffers = {
            ['default'] = actions.buf_edit,
            ['ctrl-s'] = actions.buf_split,
            ['ctrl-v'] = actions.buf_vsplit,
            ['ctrl-t'] = actions.buf_tabedit,
          },
        },
        -- FZF options for speed
        fzf_opts = {
          ['--ansi'] = true,
          ['--info'] = 'inline-right',
          ['--height'] = '100%',
          ['--layout'] = 'reverse',
          ['--border'] = 'none',
          ['--highlight-line'] = true,
        },
        -- FZF colors to match colorscheme
        fzf_colors = true,
        -- File options
        files = {
          prompt = '  ',
          multiprocess = true,
          git_icons = true,
          file_icons = true,
          color_icons = true,
          find_opts = [[-type f -not -path '*/\.git/*' -printf '%P\n']],
          rg_opts = [[--color=never --files --hidden --follow -g "!.git"]],
          fd_opts = [[--color=never --type f --hidden --follow --exclude .git]],
          cwd_prompt = false,
          cwd_prompt_shorten_len = 32,
          cwd_prompt_shorten_val = 1,
          -- Previewer
          previewer = 'builtin',
          actions = {
            ['ctrl-g'] = { actions.toggle_ignore },
            ['ctrl-h'] = { actions.toggle_hidden },
          },
        },
        -- Git files
        git = {
          files = {
            prompt = '  ',
            cmd = 'git ls-files --exclude-standard',
            multiprocess = true,
            git_icons = true,
            file_icons = true,
            color_icons = true,
          },
          status = {
            prompt = '  ',
            cmd = 'git -c color.status=false status -su',
            previewer = 'git_diff',
            file_icons = true,
            git_icons = true,
            color_icons = true,
          },
          commits = {
            prompt = '  ',
            cmd = [[git log --color --pretty=format:"%C(yellow)%h%Creset %Cgreen(%><(12)%cr%><|(12))%Creset %s %C(blue)<%an>%Creset"]],
            preview = [[git show --color=always {1}]],
          },
          bcommits = {
            prompt = '  ',
            cmd = [[git log --color --pretty=format:"%C(yellow)%h%Creset %Cgreen(%><(12)%cr%><|(12))%Creset %s %C(blue)<%an>%Creset" {file}]],
            preview = [[git show --color=always {1}]],
          },
          branches = {
            prompt = '  ',
            cmd = 'git branch --all --color',
            preview = [[git log --graph --pretty=oneline --abbrev-commit --color {1}]],
          },
          stash = {
            prompt = '  ',
            cmd = 'git stash list',
            preview = [[git stash show -p --color=always {1}]],
            actions = {
              ['default'] = actions.git_stash_apply,
              ['ctrl-x'] = { fn = actions.git_stash_drop, reload = true },
            },
          },
        },
        -- Grep options
        grep = {
          prompt = '  ',
          input_prompt = 'Grep  ',
          multiprocess = true,
          git_icons = true,
          file_icons = true,
          color_icons = true,
          rg_opts = '--column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e',
          rg_glob = false,
          glob_flag = '--iglob',
          glob_separator = '%s%-%-',
          -- Formatter for grep results
          formatter = 'path.filename_first',
          actions = {
            ['ctrl-g'] = { actions.toggle_ignore },
            ['ctrl-h'] = { actions.toggle_hidden },
          },
        },
        -- Arguments (arg list)
        args = {
          prompt = '  ',
          files_only = true,
        },
        -- Oldfiles
        oldfiles = {
          prompt = '  ',
          cwd_only = false,
          stat_file = true,
          include_current_session = true,
        },
        -- Buffers
        buffers = {
          prompt = '  ',
          file_icons = true,
          color_icons = true,
          sort_lastused = true,
          show_unloaded = true,
          cwd_only = false,
          actions = {
            ['ctrl-x'] = { fn = actions.buf_del, reload = true },
          },
        },
        -- Tabs
        tabs = {
          prompt = '  ',
          tab_title = 'Tab',
          tab_marker = '<<',
          file_icons = true,
          color_icons = true,
        },
        -- Lines
        lines = {
          prompt = '  ',
          show_unloaded = true,
          show_unlisted = false,
          no_term_buffers = true,
        },
        -- Buffer lines
        blines = {
          prompt = '  ',
          show_unlisted = true,
          no_term_buffers = false,
        },
        -- Tags
        tags = {
          prompt = '  ',
          ctags_file = nil,
          multiprocess = true,
          file_icons = true,
          git_icons = true,
          color_icons = true,
        },
        -- BTags
        btags = {
          prompt = '  ',
          ctags_file = nil,
          ctags_autogen = true,
          multiprocess = true,
          file_icons = false,
          git_icons = false,
          rg_opts = '--color=never --no-heading',
        },
        -- Colorschemes
        colorschemes = {
          prompt = '  ',
          live_preview = true,
          winopts = { height = 0.55, width = 0.30 },
        },
        -- Quickfix
        quickfix = {
          prompt = '  ',
          separator = '▏',
          file_icons = true,
          git_icons = true,
        },
        -- Quickfix stack
        quickfix_stack = {
          prompt = '  ',
        },
        -- Location list
        loclist = {
          prompt = '  ',
          separator = '▏',
          file_icons = true,
          git_icons = true,
        },
        -- Location list stack
        loclist_stack = {
          prompt = '  ',
        },
        -- Marks
        marks = {
          prompt = '󰃀 ',
        },
        -- Jumps
        jumps = {
          prompt = '  ',
        },
        -- Changes
        changes = {
          prompt = '  ',
        },
        -- Registers
        registers = {
          prompt = '󱓥 ',
        },
        -- Keymaps
        keymaps = {
          prompt = '  ',
        },
        -- Spell suggest
        spell_suggest = {
          prompt = '  ',
        },
        -- Filetypes
        filetypes = {
          prompt = '  ',
        },
        -- Packadd
        packadd = {
          prompt = '  ',
        },
        -- Help tags
        helptags = {
          prompt = '󰋖 ',
        },
        -- Man pages
        manpages = {
          prompt = '  ',
        },
        -- LSP
        lsp = {
          prompt_postfix = ' ',
          cwd_only = false,
          async_or_timeout = 5000,
          file_icons = true,
          git_icons = false,
          includeDeclaration = true,
          symbols = {
            prompt = '󰅪 ',
            symbol_style = 1,
            symbol_icons = {
              File = '󰈙',
              Module = '',
              Namespace = '󰌗',
              Package = '',
              Class = '󰌗',
              Method = '󰆧',
              Property = '',
              Field = '',
              Constructor = '',
              Enum = '',
              Interface = '󰕘',
              Function = '󰊕',
              Variable = '󰆧',
              Constant = '󰏿',
              String = '󰀬',
              Number = '󰎠',
              Boolean = '◩',
              Array = '󰅪',
              Object = '󰅩',
              Key = '󰌋',
              Null = '󰟢',
              EnumMember = '',
              Struct = '󰌗',
              Event = '',
              Operator = '󰆕',
              TypeParameter = '󰊄',
            },
            symbol_hl = function(s)
              return 'TroubleIcon' .. s
            end,
            symbol_fmt = function(s, _)
              return s .. ': '
            end,
            child_prefix = true,
            async_or_timeout = true,
          },
          code_actions = {
            prompt = '󰌵 ',
            async_or_timeout = 5000,
            winopts = {
              row = 0.40,
              height = 0.35,
              width = 0.60,
            },
          },
          finder = {
            prompt = '󰈞 ',
            file_icons = true,
            color_icons = true,
            git_icons = false,
            async = true,
            separator = ' ',
            includeDeclaration = true,
            providers = {
              { 'definitions', prefix = fzf.utils.ansi_codes.green 'def ' },
              { 'declarations', prefix = fzf.utils.ansi_codes.magenta 'dec ' },
              { 'implementations', prefix = fzf.utils.ansi_codes.green 'impl' },
              { 'typedefs', prefix = fzf.utils.ansi_codes.red 'tdef' },
              { 'references', prefix = fzf.utils.ansi_codes.blue 'ref ' },
              { 'incoming_calls', prefix = fzf.utils.ansi_codes.cyan 'in  ' },
              { 'outgoing_calls', prefix = fzf.utils.ansi_codes.yellow 'out ' },
            },
          },
        },
        diagnostics = {
          prompt = '󰒡 ',
          cwd_only = false,
          file_icons = true,
          git_icons = false,
          diag_icons = true,
          diag_source = true,
          multiline = true,
          icons = {
            ['Error'] = { icon = '', color = 'red' },
            ['Warn'] = { icon = '', color = 'yellow' },
            ['Info'] = { icon = '', color = 'blue' },
            ['Hint'] = { icon = '󰌵', color = 'magenta' },
          },
        },
        -- Previewers (for images)
        previewers = {
          builtin = {
            syntax = true,
            syntax_limit_l = 0,
            syntax_limit_b = 1024 * 1024,
            limit_b = 1024 * 1024 * 10,
            treesitter = { enabled = true, disabled = {} },
            extensions = {
              ['png'] = { '/opt/homebrew/bin/chafa', '{file}' },
              ['jpg'] = { '/opt/homebrew/bin/chafa', '{file}' },
              ['jpeg'] = { '/opt/homebrew/bin/chafa', '{file}' },
              ['gif'] = { '/opt/homebrew/bin/chafa', '{file}' },
              ['webp'] = { '/opt/homebrew/bin/chafa', '{file}' },
              ['svg'] = { '/opt/homebrew/bin/chafa', '{file}' },
            },
          },
        },
      }
    end,
    config = function(_, opts)
      require('fzf-lua').setup(opts)
      -- Register as UI select handler
      require('fzf-lua').register_ui_select()
    end,
  },
}
