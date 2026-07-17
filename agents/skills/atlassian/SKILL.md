---
name: atlassian
description: >
  CLIs and instructions to access Jira and Confluence at Roblox. Use this skill
  whenever the user wants to look up, create, update, or comment on Jira issues or
  Confluence pages — even if they just say things like "what's in ticket PROJ-123",
  "look up that Jira", "create a ticket for this", "find the Confluence doc for X",
  "search Jira for Y", or "add a comment to ALD-3". Note: first use requires a
  one-time browser OAuth; if the script prints an "ACTION REQUIRED" URL, show it to
  the user and ask them to open it in a browser before retrying.
---

# Atlassian — Jira & Confluence

Use the CLI scripts in `scripts/` — **do not construct raw curl requests**.
Auth is handled automatically: tokens are fetched from the credential broker,
cached in `~/.cache/atlassian/token_cache.json`, and refreshed only when
expired. Credentials are never echoed to the terminal.

## First-time setup (one-time OAuth, devspace only)

> **Declawd users**: skip this section. Auth is pre-injected via `DECLAWD_CREDBROKER_TOKEN_PATH` (or the legacy `CREDENTIAL_BROKER_TOKEN` env var).

Atlassian access requires a one-time browser authorisation through the
credential broker. **Every new devspace user must do this once** before any CLI command
will work.

Run any command (e.g. `jira_cli.py myself`) and watch stderr:

- **If you see "Refreshing Atlassian credentials…" followed by output** — you're
  already connected. No action needed.

- **If you see "ACTION REQUIRED — Atlassian OAuth not yet connected"** — the
  script will print a URL like:

  ```
  https://apis.simulprod.com/credential-broker/v1/connect/atlassian
  ```

  **As the agent:** Stop what you are doing, show the user this URL, and ask
  them to open it in their browser, log in with their Atlassian account, and
  confirm once they see the success page. Do not retry until the user confirms
  they have completed the OAuth flow. After they confirm, re-run the original
  command — it will succeed.


After the first successful auth the token is cached for ~1 hour and refreshed
automatically; users will not see this prompt again.

## Environment detection

The auth mechanism differs depending on where Claude is running:

| Environment | Signal | Auth path |
|-------------|--------|-----------|
| **Declawd** | `DECLAWD_CREDBROKER_TOKEN_PATH` or `CREDENTIAL_BROKER_TOKEN` is set | Pre-injected LCA token |
| **Devspace** | `coder` CLI present | `coder external-auth` GHE token → LCA exchange → broker |
| **Laptop** | `sapi` CLI present | `sapi lca-token` → broker |

The auth library tries these in order automatically: pre-injected token (fresh-read from `DECLAWD_CREDBROKER_TOKEN_PATH`, then `CREDENTIAL_BROKER_TOKEN`, then key file) → coder GHE exchange → `sapi lca-token`. Each step is skipped if its source isn't set, so devspace users with no pre-injected token automatically land on the `coder` path. No configuration needed in most cases.

Agent workload identity (agentid) is no longer minted by the skill — the local HTTP proxy injects agentid tokens into outbound requests automatically.

**When running in declawd**, the token is pre-injected — no browser OAuth step is required. The library prefers `DECLAWD_CREDBROKER_TOKEN_PATH` (fresh-on-read, so the background refresher is picked up automatically) and falls back to `CREDENTIAL_BROKER_TOKEN`.

## Quick start

`${CLAUDE_SKILL_DIR}` is set automatically by Claude Code to the absolute path
of this skill's directory, so the scripts resolve regardless of the current
working directory or where the skill is installed. The command-reference
sections below show bare `uv run jira_cli.py ...`; prefix those with
`${CLAUDE_SKILL_DIR}/scripts/` as shown here.

```bash
# Verify auth works (good first command to run)
uv run ${CLAUDE_SKILL_DIR}/scripts/jira_cli.py myself

# Jira
uv run ${CLAUDE_SKILL_DIR}/scripts/jira_cli.py search "project = PROJ AND status = 'In Progress'"

# Confluence
uv run ${CLAUDE_SKILL_DIR}/scripts/confluence_cli.py spaces
```

---

# Jira — `jira_cli.py`

## Output format

Every command prints human-readable text by default. Pass `--json` on any
command to get the structured payload instead, for scripting or programmatic
consumers. Read commands (`search`, `get`, `myself`, `projects`, `boards`,
`sprints`, `sprint-issues`, `transitions`) emit the raw Jira REST response;
mutation commands (`create`, `update`, `comment`, `transition`, `assign`) emit
a compact result object. `search --json` includes whatever `--fields` requested
(e.g. `labels`), which the text view omits.

```bash
uv run jira_cli.py search "assignee = currentUser()" --fields "summary,priority,labels" --json
uv run jira_cli.py get PROJ-123 --json
```

## Commands

### `search` — JQL issue search

```bash
uv run jira_cli.py search "project = PROJ AND status = 'In Progress'"
uv run jira_cli.py search "project = PROJ AND assignee = currentUser()" --limit 50
uv run jira_cli.py search "text ~ 'login bug'" --fields "summary,status,assignee,priority"
```

Common JQL patterns:

| JQL | Meaning |
|-----|---------|
| `project = PROJ` | All issues in project |
| `project = PROJ AND status = "In Progress"` | Filter by status |
| `project = PROJ AND assignee = currentUser()` | My issues |
| `project = PROJ AND created >= -7d` | Created in last 7 days |
| `project = PROJ AND issuetype = Bug` | Bugs only |
| `project = PROJ ORDER BY priority DESC` | Sorted |

### `get` — Single issue details

```bash
uv run jira_cli.py get PROJ-123
```

Prints summary, status, type, priority, assignee, description, comments, and available transitions.

### `create` — Create an issue

```bash
uv run jira_cli.py create --project PROJ --type Task --summary "Fix login bug" \
    --description "Users can't log in when 2FA is enabled."

uv run jira_cli.py create --project PROJ --type Bug --summary "Crash on startup" \
    --description "App crashes on launch." --priority High --labels backend crash

uv run jira_cli.py create --project PROJ --type Story --summary "Sub-task" \
    --description "Implements X" --parent PROJ-10
```

`--type` accepts any issue type your project supports (e.g. `Task`, `Bug`, `Story`, `Epic`, `Sub-task`).

### `update` — Update issue fields

```bash
uv run jira_cli.py update PROJ-123 --summary "New title"
uv run jira_cli.py update PROJ-123 --priority High
uv run jira_cli.py update PROJ-123 --description "Updated description"
uv run jira_cli.py update PROJ-123 --labels backend api
```

### `comment` — Add a comment

```bash
uv run jira_cli.py comment PROJ-123 "PR merged: https://github.com/org/repo/pull/456"
```

### `transitions` — List available state transitions

```bash
uv run jira_cli.py transitions PROJ-123
```

### `transition` — Move to a new state

```bash
uv run jira_cli.py transition PROJ-123 "In Progress"
uv run jira_cli.py transition PROJ-123 "Done"
```

The state name is matched case-insensitively. Use `transitions` to see what's available.

### `assign` — Assign an issue

```bash
uv run jira_cli.py assign PROJ-123              # assign to yourself
uv run jira_cli.py assign PROJ-123 --to <accountId>   # assign to specific user
```

### `projects` — List projects

```bash
uv run jira_cli.py projects
uv run jira_cli.py projects --query "Platform" --limit 20
```

### `myself` — Current user info

```bash
uv run jira_cli.py myself
```

Returns `displayName`, `emailAddress`, `accountId`, `timeZone`.

### `boards` — List Jira Software boards

```bash
uv run jira_cli.py boards
uv run jira_cli.py boards --project PROJ --type scrum
```

### `sprints` — List sprints on a board

```bash
uv run jira_cli.py sprints 42
uv run jira_cli.py sprints 42 --state active
```

### `sprint-issues` — Issues in a sprint

```bash
uv run jira_cli.py sprint-issues 101
uv run jira_cli.py sprint-issues 101 --limit 100
```

---

# Confluence — `confluence_cli.py`

Uses the Confluence REST API **v2** (`/wiki/api/v2/...`).

## Commands

### `spaces` — List spaces

```bash
uv run confluence_cli.py spaces
uv run confluence_cli.py spaces --type global --limit 100
```

### `space` — Get a single space

```bash
uv run confluence_cli.py space ENG          # by key
uv run confluence_cli.py space 262174       # by numeric ID
```

### `pages` — List/filter pages

```bash
uv run confluence_cli.py pages --space ENG
uv run confluence_cli.py pages --space ENG --title "Getting Started"
uv run confluence_cli.py pages --space ENG --sort -modified-date --limit 50
uv run confluence_cli.py pages --space ENG --body-format storage  # include content
```

`--sort` options: `id`, `-id`, `title`, `-title`, `created-date`, `-created-date`,
`modified-date`, `-modified-date`.

### `get` — Get a page by ID

```bash
uv run confluence_cli.py get 12345678
uv run confluence_cli.py get 12345678 --body-format view   # rendered HTML
```

### `create` — Create a page

Body is in [Confluence storage format](https://confluence.atlassian.com/doc/confluence-storage-format-790796544.html)
(XHTML subset).

```bash
uv run confluence_cli.py create --space ENG --title "My New Page" \
    --body "<p>Hello world.</p>"

# With a parent page
uv run confluence_cli.py create --space ENG --title "Child Page" \
    --body "<h1>Intro</h1><p>Content here.</p>" --parent 12345678
```

### `update` — Update a page

```bash
uv run confluence_cli.py update 12345678 --title "Revised Title"
uv run confluence_cli.py update 12345678 --body "<p>Updated content.</p>"
```

Version increment is handled automatically.

### `children` — List child pages

```bash
uv run confluence_cli.py children 12345678
```

### `labels` — Manage page labels

```bash
uv run confluence_cli.py labels 12345678           # list labels
uv run confluence_cli.py labels 12345678 --add my-label
uv run confluence_cli.py labels 12345678 --remove my-label
```

---

## Auth notes

- See **First-time setup** at the top of this document for the one-time OAuth flow.
- Tokens are short-lived (~1 hour). The scripts check expiry before each run and
  refresh silently when needed.
- Cache location: `~/.cache/atlassian/token_cache.json` (mode 0600).
  Delete this file to force a full re-auth.
- **Cloud selection**: The credential broker's OAuth app is registered in the
  `roblox-partner` Atlassian instance, so Atlassian returns that cloud first in
  `accessible-resources`. The skill corrects for this by preferring the cloud
  named `roblox` when present. To override (e.g. for contractors who only have
  `roblox-partner`), set `ATLASSIAN_CLOUD_NAME=roblox-partner`.

## Error codes

| Code | Meaning |
|------|---------|
| 401 | Token expired — scripts auto-refresh once and retry |
| 403 | Insufficient Jira/Confluence permissions |
| 404 | Resource not found |
| 429 | Rate limited — wait and retry |
