-- Java Language Server Configuration
-- jdtls (Eclipse JDT Language Server)

return {
    jdtls = {
        -- jdtls requires special setup, but basic config works via mason
        settings = {
            java = {
                -- Enable inlay hints
                inlayHints = {
                    parameterNames = {
                        enabled = 'all',
                    },
                },
                -- Code formatting
                format = {
                    enabled = true,
                    settings = {
                        profile = 'GoogleStyle',
                    },
                },
                -- Code completion
                completion = {
                    favoriteStaticMembers = {
                        'org.junit.Assert.*',
                        'org.junit.Assume.*',
                        'org.junit.jupiter.api.Assertions.*',
                        'org.junit.jupiter.api.Assumptions.*',
                        'org.junit.jupiter.api.DynamicContainer.*',
                        'org.junit.jupiter.api.DynamicTest.*',
                        'org.mockito.Mockito.*',
                        'org.mockito.ArgumentMatchers.*',
                        'org.mockito.Answers.*',
                    },
                    importOrder = {
                        'java',
                        'javax',
                        'com',
                        'org',
                    },
                },
                -- Sources
                sources = {
                    organizeImports = {
                        starThreshold = 9999,
                        staticStarThreshold = 9999,
                    },
                },
                -- Code generation
                codeGeneration = {
                    toString = {
                        template = '${object.className}{${member.name()}=${member.value}, ${otherMembers}}',
                    },
                    useBlocks = true,
                },
            },
        },
    },
}
