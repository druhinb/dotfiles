-- Go Language Server Configuration
-- gopls is the official Go language server

return {
    gopls = {
        settings = {
            gopls = {
                -- Enable all analyses
                analyses = {
                    unusedparams = true,
                    shadow = true,
                    nilness = true,
                    unusedwrite = true,
                    useany = true,
                },
                -- Enable static check
                staticcheck = true,
                -- Inlay hints
                hints = {
                    assignVariableTypes = true,
                    compositeLiteralFields = true,
                    compositeLiteralTypes = true,
                    constantValues = true,
                    functionTypeParameters = true,
                    parameterNames = true,
                    rangeVariableTypes = true,
                },
                -- Code lenses
                codelenses = {
                    gc_details = true,
                    generate = true,
                    regenerate_cgo = true,
                    run_govulncheck = true,
                    test = true,
                    tidy = true,
                    upgrade_dependency = true,
                    vendor = true,
                },
                -- Use gofumpt for stricter formatting
                gofumpt = true,
                -- Semantic tokens for better highlighting
                semanticTokens = true,
                -- Complete unimported packages
                completeUnimported = true,
                -- Use placeholders in completions
                usePlaceholders = true,
            },
        },
    },
}
