-- Markdown Language Server Configuration
-- marksman for markdown intelligence + ltex for grammar/spelling

return {
    -- Marksman: Markdown LSP with wiki-links, references, and more
    marksman = {},

    -- LTeX: Grammar and spell checking (supports many languages)
    ltex = {
        filetypes = { 'markdown', 'text', 'latex', 'tex', 'bib', 'gitcommit' },
        settings = {
            ltex = {
                language = 'en-US',
                -- Disable specific rules if too noisy
                disabledRules = {
                    ['en-US'] = { 'MORFOLOGIK_RULE_EN_US' }, -- Disable spell check (use nvim-cmp for that)
                },
                -- Add words to dictionary
                dictionary = {},
                -- Check grammar in code comments
                checkFrequency = 'save',
            },
        },
    },
}
