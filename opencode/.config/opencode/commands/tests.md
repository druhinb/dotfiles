---
description: Detect and run the project's test suite, then report failures
agent: build
---
Detect the project's test runner and run the full suite. Common signals:

- Node: `package.json` scripts (`test`, `test:ci`), jest, vitest, mocha, playwright.
- Python: pytest, unittest, tox, nox.
- Go: `go test ./...`.
- Rust: `cargo test`.
- C/C++: ctest, Makefile `test`/`check` targets.
- Generic: `Makefile` targets, `just` recipes.

Run the appropriate command, then:
- Summarize pass/fail counts.
- For each failure, show `file_path:line_number`, the failure message, and a suggested fix.
- Do not modify files unless the user asks. If no test runner is detectable, say so and stop.
