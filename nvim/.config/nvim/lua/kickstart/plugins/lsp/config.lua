-- Configuration Files Language Server Configuration
-- YAML, JSON, TOML support

return {
    -- YAML language server
    yamlls = {
        settings = {
            yaml = {
                -- Enable schema validation
                schemaStore = {
                    enable = true,
                    url = 'https://www.schemastore.org/api/json/catalog.json',
                },
                schemas = {
                    -- Common schemas
                    ['https://json.schemastore.org/github-workflow.json'] = '/.github/workflows/*',
                    ['https://json.schemastore.org/github-action.json'] = '/.github/actions/*/action.yml',
                    ['https://json.schemastore.org/dependabot-2.0.json'] = '/.github/dependabot.yml',
                    ['https://json.schemastore.org/docker-compose.json'] = 'docker-compose*.yml',
                    ['https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json'] =
                    'docker-compose*.yml',
                    ['https://json.schemastore.org/pre-commit-config.json'] = '.pre-commit-config.yml',
                },
                -- Format options
                format = {
                    enable = true,
                    singleQuote = false,
                    bracketSpacing = true,
                },
                -- Validation
                validate = true,
                -- Hover info
                hover = true,
                -- Completion
                completion = true,
            },
        },
    },

    -- JSON language server
    jsonls = {
        settings = {
            json = {
                validate = { enable = true },
                format = { enable = true },
            },
        },
        -- Configure schemas on attach
        on_attach = function(client, bufnr)
            -- Try to load schemastore if available
            local ok, schemastore = pcall(require, 'schemastore')
            if ok and client.config and client.config.settings then
                client.config.settings.json.schemas = schemastore.json.schemas()
            end
        end,
    },

    -- TOML language server
    taplo = {
        settings = {
            taplo = {
                formatter = {
                    alignEntries = false,
                    alignComments = true,
                    arrayTrailingComma = true,
                    arrayAutoExpand = true,
                    arrayAutoCollapse = true,
                    compactArrays = true,
                    compactInlineTables = false,
                    columnWidth = 80,
                    indentTables = false,
                    indentEntries = false,
                    reorderKeys = true,
                    trailingNewline = true,
                },
            },
        },
    },
}
