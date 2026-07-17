---
name: portal
description: >
    Use when the user wants to interact with Engine Portal data — engine fast flags,
    channels, TestHub, or Portal Insights. Also trigger when reading engine code that
    references fast flags and the user wants to understand the current flag state.
    Note: first use requires a one-time browser OAuth; if the script prints an
    "ACTION REQUIRED" URL, show it to the user and ask them to open it in a browser
    before retrying.
---

# Portal

Interact with the Engine Portal.

## Resources
- For flags look at [fastflags.md](references/fastflags.md)
- For channels look at [channels.md](references/channels.md)
- For TestHub look at [testhub.md](references/testhub.md)
- For insights look at [insights.md](references/insights.md)

## One-time OAuth setup

If the CLI exits with code 2, show the user the URL it prints and ask them to
open it in a browser and approve access. This is a one-time step.
