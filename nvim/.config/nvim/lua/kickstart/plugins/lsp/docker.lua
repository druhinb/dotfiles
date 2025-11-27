-- Docker/Container Language Server Configuration

return {
    -- Dockerfile language server
    dockerls = {
        settings = {
            docker = {
                languageserver = {
                    formatter = {
                        ignoreMultilineInstructions = true,
                    },
                },
            },
        },
    },

    -- Docker Compose language server
    docker_compose_language_service = {},
}
