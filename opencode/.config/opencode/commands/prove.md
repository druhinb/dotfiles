---
description: "Generate exhaustive, adversarial tests that guarantee correctness"
---
Write an exhaustive test suite for: $ARGUMENTS

Target the specified file, function, or module. Cover every code path, boundary,
error condition, and adversarial input. Apply mutation-testing logic — every
flipped operator or deleted line must cause at least one test to fail.

After writing tests, run the suite and iterate until all tests pass against the
existing correct implementation. Report any real bugs discovered as findings.
