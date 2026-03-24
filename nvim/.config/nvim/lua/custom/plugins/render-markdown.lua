local have_nerd = vim.g.have_nerd_font

return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    -- Enable/disable rendering by default (can be toggled)
    enabled = true,
    -- Maximum file size to render (5MB)
    max_file_size = 5.0,
    -- Debounce time for rendering updates
    debounce = 100,
    
    -- Preset styling (obsidian-like)
    preset = 'obsidian',
    
    -- Rendering options
    render_modes = { 'n', 'c', 'i' }, -- Render in normal, command, and insert modes
    
    -- Anti-conceal settings: never show source in these contexts
    anti_conceal = {
      enabled = true,
    },
    
    -- Heading configuration (Obsidian-style)
    heading = {
      enabled = true,
      sign = true,
      icons = have_nerd and { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' } or { '# ', '## ', '### ', '#### ', '##### ', '###### ' },
      signs = have_nerd and { '󰫎 ' } or { '●' },
      width = 'full',
      backgrounds = {
        'RenderMarkdownH1Bg',
        'RenderMarkdownH2Bg',
        'RenderMarkdownH3Bg',
        'RenderMarkdownH4Bg',
        'RenderMarkdownH5Bg',
        'RenderMarkdownH6Bg',
      },
      foregrounds = {
        'RenderMarkdownH1',
        'RenderMarkdownH2',
        'RenderMarkdownH3',
        'RenderMarkdownH4',
        'RenderMarkdownH5',
        'RenderMarkdownH6',
      },
    },
    
    -- Code block rendering
    code = {
      enabled = true,
      sign = true,
      style = 'full',
      position = 'left',
      width = 'full',
      left_pad = 2,
      right_pad = 2,
      min_width = 0,
      border = 'thin',
      above = '▄',
      below = '▀',
      highlight = 'RenderMarkdownCode',
      highlight_inline = 'RenderMarkdownCodeInline',
    },
    
    -- Dash/bullet rendering
    bullet = {
      enabled = true,
      icons = { '●', '○', '◆', '◇' },
      right_pad = 1,
      highlight = 'RenderMarkdownBullet',
    },
    
    -- Checkbox rendering
    checkbox = {
      enabled = true,
      unchecked = {
        icon = have_nerd and '󰄱 ' or '[ ] ',
        highlight = 'RenderMarkdownUnchecked',
        scope_highlight = nil,
      },
      checked = {
        icon = have_nerd and '󰱒 ' or '[x] ',
        highlight = 'RenderMarkdownChecked',
        scope_highlight = nil,
      },
      custom = {
        todo = { raw = '[-]', rendered = have_nerd and '󰥔 ' or '[-] ', highlight = 'RenderMarkdownTodo' },
        important = { raw = '[!]', rendered = have_nerd and ' ' or '[!] ', highlight = 'DiagnosticWarn' },
        question = { raw = '[?]', rendered = have_nerd and ' ' or '[?] ', highlight = 'DiagnosticInfo' },
      },
    },
    
    -- Quote block rendering
    quote = {
      enabled = true,
      icon = '▋',
      repeat_linebreak = false,
      highlight = 'RenderMarkdownQuote',
    },
    
    -- Pipe table rendering
    pipe_table = {
      enabled = true,
      style = 'full',
      cell = 'padded',
      border = {
        '┌', '┬', '┐',
        '├', '┼', '┤',
        '└', '┴', '┘',
        '│', '─',
      },
      alignment_indicator = '━',
      head = 'RenderMarkdownTableHead',
      row = 'RenderMarkdownTableRow',
    },
    
    -- Callout rendering (Obsidian-style)
    callout = {
      note = { raw = '[!NOTE]', rendered = '󰋽 Note', highlight = 'RenderMarkdownInfo' },
      tip = { raw = '[!TIP]', rendered = '󰌶 Tip', highlight = 'RenderMarkdownSuccess' },
      important = { raw = '[!IMPORTANT]', rendered = '󰅾 Important', highlight = 'RenderMarkdownHint' },
      warning = { raw = '[!WARNING]', rendered = '󰀪 Warning', highlight = 'RenderMarkdownWarn' },
      caution = { raw = '[!CAUTION]', rendered = '󰳦 Caution', highlight = 'RenderMarkdownError' },
      abstract = { raw = '[!ABSTRACT]', rendered = '󰨸 Abstract', highlight = 'RenderMarkdownInfo' },
      summary = { raw = '[!SUMMARY]', rendered = '󰨸 Summary', highlight = 'RenderMarkdownInfo' },
      tldr = { raw = '[!TLDR]', rendered = '󰨸 Tldr', highlight = 'RenderMarkdownInfo' },
      info = { raw = '[!INFO]', rendered = '󰋽 Info', highlight = 'RenderMarkdownInfo' },
      todo = { raw = '[!TODO]', rendered = '󰥔 Todo', highlight = 'RenderMarkdownInfo' },
      hint = { raw = '[!HINT]', rendered = '󰌶 Hint', highlight = 'RenderMarkdownSuccess' },
      success = { raw = '[!SUCCESS]', rendered = '󰄬 Success', highlight = 'RenderMarkdownSuccess' },
      check = { raw = '[!CHECK]', rendered = '󰄬 Check', highlight = 'RenderMarkdownSuccess' },
      done = { raw = '[!DONE]', rendered = '󰄬 Done', highlight = 'RenderMarkdownSuccess' },
      question = { raw = '[!QUESTION]', rendered = '󰘥 Question', highlight = 'RenderMarkdownWarn' },
      help = { raw = '[!HELP]', rendered = '󰘥 Help', highlight = 'RenderMarkdownWarn' },
      faq = { raw = '[!FAQ]', rendered = '󰘥 Faq', highlight = 'RenderMarkdownWarn' },
      attention = { raw = '[!ATTENTION]', rendered = '󰀪 Attention', highlight = 'RenderMarkdownWarn' },
      failure = { raw = '[!FAILURE]', rendered = '󰅖 Failure', highlight = 'RenderMarkdownError' },
      fail = { raw = '[!FAIL]', rendered = '󰅖 Fail', highlight = 'RenderMarkdownError' },
      missing = { raw = '[!MISSING]', rendered = '󰅖 Missing', highlight = 'RenderMarkdownError' },
      danger = { raw = '[!DANGER]', rendered = '󰳦 Danger', highlight = 'RenderMarkdownError' },
      error = { raw = '[!ERROR]', rendered = '󰅖 Error', highlight = 'RenderMarkdownError' },
      bug = { raw = '[!BUG]', rendered = '󰨰 Bug', highlight = 'RenderMarkdownError' },
      example = { raw = '[!EXAMPLE]', rendered = '󰉹 Example', highlight = 'RenderMarkdownHint' },
      quote = { raw = '[!QUOTE]', rendered = '󱆨 Quote', highlight = 'RenderMarkdownQuote' },
      cite = { raw = '[!CITE]', rendered = '󱆨 Cite', highlight = 'RenderMarkdownQuote' },
    },
    
    -- Link rendering
    link = {
      enabled = true,
      image = have_nerd and '󰥶 ' or 'IMG ',
      hyperlink = have_nerd and '󰌹 ' or 'LINK ',
      highlight = 'RenderMarkdownLink',
      custom = {
        web = { pattern = '^http[s]?://', icon = have_nerd and '󰖟 ' or 'WEB ', highlight = 'RenderMarkdownLink' },
      },
    },
    
    -- Sign column rendering
    sign = {
      enabled = true,
      highlight = 'RenderMarkdownSign',
    },
    
    -- Win options to set when rendering
    win_options = {
      conceallevel = {
        default = vim.o.conceallevel,
        rendered = 3,
      },
      concealcursor = {
        default = vim.o.concealcursor,
        rendered = '',
      },
    },
  },
  
  config = function(_, opts)
    require('render-markdown').setup(opts)
    
    -- Keymaps for toggling between reading and source mode
    vim.keymap.set('n', '<leader>mr', '<cmd>RenderMarkdown toggle<cr>', {
      desc = 'Toggle Markdown Rendering (Reading/Source Mode)',
    })
    
    vim.keymap.set('n', '<leader>me', '<cmd>RenderMarkdown enable<cr>', {
      desc = 'Enable Markdown Rendering (Reading Mode)',
    })
    
    vim.keymap.set('n', '<leader>md', '<cmd>RenderMarkdown disable<cr>', {
      desc = 'Disable Markdown Rendering (Source Mode)',
    })
  end,
}
