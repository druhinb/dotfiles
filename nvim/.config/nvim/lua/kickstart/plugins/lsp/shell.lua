-- Shell Scripting Language Server Configuration
-- bashls for Bash/Shell scripts

return {
    bashls = {
        filetypes = { 'sh', 'bash', 'zsh' },
        settings = {
            bashIde = {
                -- Enable shellcheck integration
                shellcheckPath = 'shellcheck',
                shellcheckArguments = {},
                -- Glob pattern for finding files to index
                globPattern = '*@(.sh|.inc|.bash|.command)',
            },
        },
    },
}
