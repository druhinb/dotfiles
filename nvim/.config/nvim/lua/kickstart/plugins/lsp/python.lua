-- basedpyright: A community fork of pyright with additional features
--   - Better type inference and error messages
--   - More strict checks available
--   - Active community development
--
-- ruff: An extremely fast Python linter and formatter written in Rust
--   - Replaces flake8, black, isort, and many other tools
--   - 10-100x faster than traditional Python linters
--

return {
  -- Basedpyright - Type checker and language server
  -- https://github.com/detachhead/basedpyright
  basedpyright = {
    settings = {
      basedpyright = {
        analysis = {
          -- Type checking mode: off, basic, standard, strict, all
          -- 'standard' is a good balance between strictness and practicality
          typeCheckingMode = 'standard',

          autoSearchPaths = true,

          useLibraryCodeForTypes = true,

          diagnosticMode = 'openFilesOnly', -- or 'workspace' for full project analysis

          inlayHints = {
            variableTypes = true,
            functionReturnTypes = true,
            callArgumentNames = true,
            genericTypes = false,
          },

          diagnosticSeverityOverrides = {
            reportMissingImports = 'error',
            reportUndefinedVariable = 'error',
            reportUnboundVariable = 'error',
            reportGeneralTypeIssues = 'error',

            reportMissingTypeStubs = 'warning',
            reportOptionalMemberAccess = 'warning',
            reportOptionalSubscript = 'warning',
            reportPrivateUsage = 'warning',
            reportConstantRedefinition = 'warning',
            reportAssertAlwaysTrue = 'warning',
            reportSelfClsParameterName = 'warning',

            reportUnusedImport = 'none',
            reportUnusedVariable = 'none',
            reportUnusedFunction = 'none',
            reportDuplicateImport = 'none',

            reportUnknownMemberType = 'none',
            reportUnknownArgumentType = 'none',
            reportUnknownVariableType = 'none',
            reportUnknownLambdaType = 'none',

            reportMissingParameterType = 'none',
            reportMissingReturnType = 'none',
            reportImplicitStringConcatenation = 'none',
            reportInvalidStubStatement = 'none',
            reportIncompleteStub = 'none',
          },
        },
      },
    },
  },

  -- Ruff - Fast linter and formatter
  -- https://github.com/astral-sh/ruff
  ruff = {
    init_options = {
      settings = {
        logLevel = 'warn',

        showSyntaxErrors = true,

        organizeImports = true,

        fixAll = true,

        codeAction = {
          fixViolation = {
            enable = true,
          },
          disableRuleComment = {
            enable = true,
          },
        },

        lint = {
          select = {
            'E', -- pycodestyle errors
            'W', -- pycodestyle warnings
            'F', -- Pyflakes
            'I', -- isort (import sorting)
            'B', -- flake8-bugbear
            'C4', -- flake8-comprehensions
            'UP', -- pyupgrade
            'ARG', -- flake8-unused-arguments
            'SIM', -- flake8-simplify
            'TCH', -- flake8-type-checking
            'PTH', -- flake8-use-pathlib
            'RUF', -- Ruff-specific rules
          },
          -- Ignore specific rules
          ignore = {
            'E501', -- Line too long
            'PLR0913', -- Too many arguments
            'PLR2004', -- Magic value comparison
          },
        },
      },
    },
  },
}
