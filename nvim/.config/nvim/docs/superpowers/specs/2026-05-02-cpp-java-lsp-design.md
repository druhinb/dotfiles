# C/C++ and Java LSP Rearchitecture

**Date:** 2026-05-02
**Approach:** Option B — Language plugin files (LazyVim style)

## Problem

Both C/C++ and Java LSP setups are broken in different ways:

**C/C++:**
- `codelldb` DAP path is hardcoded to `''` (empty string) — debugger never launches
- No `clangd_extensions.nvim` — missing VSCode-parity features (AST viewer, inlay type hints, header/source switch, type hierarchy)
- No CMake tooling — `compile_commands.json` must be generated manually

**Java:**
- `jdtls` is wired through the generic `vim.lsp.config` loop in the central `servers` table
- jdtls is workspace-scoped: one server instance per project. The generic loop starts a single shared server for all Java files, corrupting the project index when multiple projects are open
- No debug adapter bundle (java-debug-adapter)
- No test runner bundle (vscode-java-test)
- No Java-specific code action keymaps (organize imports, extract method/variable/constant)

## Solution

Remove `clangd` and `jdtls` from the central `servers` table in `lspconfig.lua`. Create two self-contained language plugin files following LazyVim's `lang/` pattern. All other languages remain untouched.

---

## C/C++ Design (`lua/custom/plugins/lang-cpp.lua`)

### Plugins

| Plugin | Role |
|---|---|
| `neovim/nvim-lspconfig` (clangd) | LSP engine — already a dependency, just reconfigured |
| `p00f/clangd_extensions.nvim` | VSCode-parity: AST viewer, inlay type hints, header↔source switch, type hierarchy |
| `Civitasv/cmake-tools.nvim` | CMake project management: auto-detects CMakeLists.txt, generates compile_commands.json, build/run/debug targets |

### clangd Configuration

Flags for large, complex projects:
```lua
cmd = {
  'clangd',
  '--background-index',
  '--background-index-priority=normal',
  '--clang-tidy',
  '--all-scopes-completion',
  '--completion-style=detailed',
  '--header-insertion=iwyu',
  '--pch-storage=memory',       -- keeps index in RAM; faster for large codebases
  '--function-arg-placeholders',
  '--cross-file-rename',
  '--fallback-style=llvm',
}
```

No `--compile-commands-dir` hardcoded — clangd walks up the directory tree automatically, so CMake, Make, Bazel, and manually-placed `compile_commands.json` all work without configuration.

`offsetEncoding` set to `'utf-16'` via capabilities (required by clangd, prevents warning spam).

### clangd_extensions.nvim

- Inlay type hints: parameter types, return types (better than Neovim built-in for C++)
- AST viewer: `<leader>cK` (`<leader>cA` is already the global "Source Action" keymap)
- Memory usage viewer: `<leader>cM`
- Type hierarchy: `<leader>cH`
- Switch header ↔ source: `<A-o>` (matches VSCode C/C++ extension default)

### cmake-tools.nvim

Active only when `CMakeLists.txt` is found in the project root. On CMake projects it:
- Runs `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` automatically so clangd gets compile commands
- Provides build target picker, run, and debug integration
- Keymaps under `<leader>m` (build, run, debug, configure, clean)

For non-CMake projects (Make, Bazel, plain `compile_commands.json`), cmake-tools stays dormant. clangd still works as long as `compile_commands.json` exists anywhere in the tree.

### DAP Fix

Root cause in `debug.lua`:
```lua
local extension_path = '' -- codelldb:get_install_handle() .. '/extension/'
```
The `get_install_handle()` call was commented out, leaving an empty path.

Fix: move C/C++/Rust codelldb config out of `debug.lua` into `lang-cpp.lua`, using the correct Mason API:
```lua
local codelldb = mason_registry.get_package('codelldb')
local ext = codelldb:get_install_path() .. '/extension/'
local codelldb_path = ext .. 'adapter/codelldb'
local liblldb_path  = ext .. 'lldb/lib/liblldb' .. (vim.fn.has('mac') == 1 and '.dylib' or '.so')
```

DAP configurations: `launch` (prompts for executable, searches `build/`, `cmake-build-debug/`, `target/debug/`, `out/`, `bin/`) and `attach to process`.

### Mason ensure_installed additions

- `clangd`

(`clang-format`, `cpplint`, `codelldb` are already present.)

---

## Java Design (`lua/custom/plugins/lang-java.lua`)

### Plugin

| Plugin | Role |
|---|---|
| `mfussenegger/nvim-jdtls` | Full Java LSP lifecycle manager — per-project workspaces, DAP bundles, test bundles |

### Per-project Workspace Management

Started via `FileType java` autocmd instead of the generic `vim.lsp.config` loop.

Project root detection (walks up from current file):
- `pom.xml` → Maven project
- `build.gradle` / `build.gradle.kts` → Gradle project
- `.git` → fallback root

Workspace data directory: `~/.cache/nvim/jdtls/<hash-of-project-root>` — one directory per project, preventing index corruption.

### JVM Configuration

Tuned for large codebases:
```lua
'-Xmx2G',
'-Xms256m',
'-XX:+UseParallelGC',
'-XX:GCTimeRatio=4',
'-XX:AdaptiveSizePolicyWeight=90',
'-Dsun.zip.disableMemoryMapping=true',
```

### Lombok Support

At startup, check a fixed set of known locations for `lombok.jar`: project root, `lib/`, `.mvn/`. Does NOT scan `~/.m2` (too large). If found, pass `-javaagent:<path>` in `jvm_args`. If not found, proceed without it — no error.

### DAP Bundles

Two bundles loaded into jdtls at startup:
- `java-debug-adapter` (Mason package) — enables full DAP step-through debugging, identical to VSCode's Debugger for Java
- `vscode-java-test` (Mason package) — enables run/debug of individual tests and test classes

Bundle paths resolved from Mason install directories at startup.

### Java-specific Keymaps (Java buffers only)

| Key | Action |
|---|---|
| `<leader>co` | Organize imports |
| `<leader>cv` | Extract variable |
| `<leader>cV` | Extract variable (all occurrences) |
| `<leader>cm` | Extract method (works in visual mode) |
| `<leader>cC` | Extract constant |
| `<leader>ct` | Run nearest test |
| `<leader>cT` | Run test class |
| `<leader>cu` | Update project config (re-sync after pom.xml / build.gradle changes) |

### Mason ensure_installed additions

- `jdtls`
- `java-debug-adapter`
- `java-test`
- `google-java-format` (formatter, wired into conform.nvim for Java filetypes)

---

## Files Changed

| File | Change |
|---|---|
| `lua/kickstart/plugins/lspconfig.lua` | Remove `clangd` and `jdtls` from `servers` table; add `google-java-format` to `ensure_installed` |
| `lua/kickstart/plugins/debug.lua` | Remove broken codelldb block (C/C++/Rust DAP moves to lang-cpp.lua) |
| `lua/custom/plugins/lang-cpp.lua` | **New file** — clangd + clangd_extensions + cmake-tools + codelldb DAP |
| `lua/custom/plugins/lang-java.lua` | **New file** — nvim-jdtls with per-project workspaces, DAP bundles, test runner, keymaps |

## Files Not Changed

Everything else — Python, Rust, Go, TypeScript, Lua, Shell, Docker, SQL, Markdown, YAML, JSON, TOML. The central `servers` table, `on_attach` handler, diagnostic config, and keymap setup all remain untouched.
