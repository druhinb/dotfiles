-- Web Development Language Server Configuration
-- HTML, CSS, SCSS, LESS, Emmet

return {
    html = {
        filetypes = { 'html', 'htmldjango' },
    },

    cssls = {
        settings = {
            css = {
                validate = true,
                lint = {
                    unknownAtRules = 'ignore',
                },
            },
            scss = {
                validate = true,
            },
            less = {
                validate = true,
            },
        },
    },

    emmet_language_server = {
        filetypes = { 'html', 'css', 'scss', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    },
}
