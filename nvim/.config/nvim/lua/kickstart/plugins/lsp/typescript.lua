-- TypeScript/JavaScript Language Server Configuration

return {
    ts_ls = {
        settings = {
            typescript = {
                inlayHints = {
                    -- Only show parameter names for literals (numbers, strings, booleans)
                    includeInlayParameterNameHints = 'literals',
                    includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                    -- Disable noisy type hints
                    includeInlayFunctionParameterTypeHints = false,
                    includeInlayVariableTypeHints = false,
                    includeInlayPropertyDeclarationTypeHints = false,
                    -- Keep return type hints (useful)
                    includeInlayFunctionLikeReturnTypeHints = true,
                    includeInlayEnumMemberValueHints = false,
                },
            },
            javascript = {
                inlayHints = {
                    includeInlayParameterNameHints = 'literals',
                    includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                    includeInlayFunctionParameterTypeHints = false,
                    includeInlayVariableTypeHints = false,
                    includeInlayPropertyDeclarationTypeHints = false,
                    includeInlayFunctionLikeReturnTypeHints = true,
                    includeInlayEnumMemberValueHints = false,
                },
            },
        },
    },
}
