---
name: airtable
description: >
  CLI and instructions to read and write Airtable bases, tables, records, and schema.
  Use this skill when the user wants to query Airtable, fetch records, create or update
  rows, delete records, or manage table/field schema. Write commands are gated by
  --dry-run previews and (for deletes) explicit --yes confirmation.
---

# Airtable — Read + Write Access

Use the CLI script in `scripts/` — **do not construct raw curl requests**.
Auth is handled automatically: tokens are fetched from the credential broker,
cached in `~/.cache/rbx-skills/airtable/token_cache.json`, and refreshed only when
expired. Credentials are never echoed to the terminal.

## First-time setup (one-time OAuth, devspace only)

> **Declawd users**: skip this section. Auth is pre-injected via `DECLAWD_CREDBROKER_TOKEN_PATH` (or the legacy `CREDENTIAL_BROKER_TOKEN` env var).

Airtable access requires a one-time browser authorisation through the
credential broker. **Every new devspace user must do this once** before any CLI command
will work.

Run any command (e.g. `airtable_cli.py bases`) and watch stderr:

- **If you see "Refreshing Airtable credentials…" followed by output** — you're
  already connected. No action needed.

- **If you see "ACTION REQUIRED — Airtable OAuth not yet connected"** — the
  script will print a URL like:

  ```
  https://apis.simulprod.com/credential-broker/v1/connect/airtable
  ```

  **As the agent:** Stop what you are doing, show the user this URL, and ask
  them to open it in their browser, log in with their Airtable account, and
  confirm once they see the success page. Do not retry until the user confirms
  they have completed the OAuth flow. After they confirm, re-run the original
  command — it will succeed.

After the first successful auth the token is cached for ~1 hour and refreshed
automatically; users will not see this prompt again.

## Environment detection

The auth mechanism differs depending on where Claude is running:

| Environment | Signal | Auth path |
|-------------|--------|-----------|
| **Devspace** (Coder) | `coder` CLI present *and* no pre-injected token | Automatic via `coder external-auth` → LCA exchange |
| **Declawd** | `DECLAWD_CREDBROKER_TOKEN_PATH` or `CREDENTIAL_BROKER_TOKEN` is set | Pre-injected LCA token |

The auth library picks the right path automatically based on what's set; devspace users don't need to do anything. **In declawd**, the token is pre-injected — no browser OAuth step is required. The library prefers `DECLAWD_CREDBROKER_TOKEN_PATH` (fresh-on-read, so declawd's background refresher is picked up automatically) and falls back to `CREDENTIAL_BROKER_TOKEN` as a stale snapshot.

## Quick start

```bash
SKILL_DIR=".claude/skills/airtable/scripts"

# Reads
uv run $SKILL_DIR/airtable_cli.py bases
uv run $SKILL_DIR/airtable_cli.py tables appXXXXXXXXXXXXX
uv run $SKILL_DIR/airtable_cli.py records appXXXXXXXXXXXXX "Table Name" --limit 20

# Writes (always preview with --dry-run first)
uv run $SKILL_DIR/airtable_cli.py create-records appXXX "Table" \
    --records '[{"fields":{"Name":"Alice"}}]' --dry-run
```

## Safety rules for write operations

1. **Always run `--dry-run` first** for any `create-*`, `update-*`, `replace-*`,
   `upsert-*`, or schema command. Inspect the printed method, URL, and body
   before re-running without `--dry-run`.
2. **`delete-records` requires `--yes`.** Without it, the command refuses to
   run. Use `--dry-run` to preview the URL.
3. **Updates vs. replaces**: `update-records` (PATCH) preserves fields you
   don't mention; `replace-records` (PUT) **clears** them. Prefer `update-records`
   unless you specifically need to wipe-and-set.
4. **Schema changes are usually irreversible** (no public API for deleting
   tables or fields). Confirm with the user before running `create-table`,
   `create-field`, or `update-*` schema commands.
5. **Auto-batching**: write commands automatically chunk requests in groups of
   10 records (Airtable's hard cap). You can pass arrays of any length.

---

# `airtable_cli.py`

Base IDs start with `app`, table IDs with `tbl`, field IDs with `fld`,
record IDs with `rec`, and workspace IDs with `wsp`. Table names are
case-sensitive (quote them when they contain spaces).

## Read commands

### `bases` — List accessible bases

```bash
uv run airtable_cli.py bases
```

### `tables` — List tables in a base

```bash
uv run airtable_cli.py tables appXXXXXXXXXXXXX
```

### `records` — List records from a table

```bash
uv run airtable_cli.py records appXXX "Table Name"
uv run airtable_cli.py records appXXX "Table Name" --limit 50
uv run airtable_cli.py records appXXX "Table Name" --view "Grid view"
uv run airtable_cli.py records appXXX "Table Name" --formula "{Status}='Active'"
```

| Flag | Description |
|------|-------------|
| `--limit N` | Max records (default: 100) |
| `--view NAME` | Airtable view to use |
| `--formula FORMULA` | filterByFormula expression |
| `--sort FIELD` | Field name to sort by |
| `--direction asc\|desc` | Sort direction (default: asc) |
| `--fields FIELD ...` | Only return these fields |

### `record` — Get a single record

```bash
uv run airtable_cli.py record appXXX "Table Name" recXXXXXXXXXXXXX
```

## Write commands — records

All write commands accept records via `--records '<json>'` (inline) **or**
`--file <path>` (file or `-` for stdin), and support `--dry-run`.

### `create-records` — Create new records

```bash
uv run airtable_cli.py create-records appXXX "Table" \
    --records '[{"fields":{"Name":"Alice","Status":"Active"}}]'
```

Auto-batches in groups of 10. Each entry must be `{"fields": {...}}`.

### `update-records` — Patch existing records (preserves unspecified fields)

```bash
uv run airtable_cli.py update-records appXXX "Table" \
    --records '[{"id":"recAAA","fields":{"Status":"Done"}}]'
```

### `replace-records` — Replace existing records (PUT; clears unspecified fields)

```bash
uv run airtable_cli.py replace-records appXXX "Table" \
    --records '[{"id":"recAAA","fields":{"Name":"Alice","Status":"Done"}}]'
```

> **Use with care.** Any field not listed will be cleared.

### `upsert-records` — Upsert by merge field(s)

```bash
uv run airtable_cli.py upsert-records appXXX "Table" \
    --merge-on Email \
    --records '[{"fields":{"Email":"a@x.com","Name":"Alice"}}]'
```

| Flag | Description |
|------|-------------|
| `--merge-on FIELD ...` | One or more field names to match against (required) |
| `--typecast` | Let Airtable coerce string values to the field's type |

### `delete-records` — Delete records by ID

```bash
uv run airtable_cli.py delete-records appXXX "Table" \
    --record-ids recAAA recBBB --yes
```

Requires `--yes` to actually delete. Auto-batches in groups of 10.

## Write commands — schema

Schema operations do not have public delete APIs. **Always preview with
`--dry-run` first and confirm with the user.**

### `create-base` — Create a new base in a workspace

```bash
uv run airtable_cli.py create-base \
    --workspace-id wspXXXXXXXXXXXXX \
    --name "New Base" \
    --tables '[{"name":"T1","fields":[{"name":"Name","type":"singleLineText"}]}]'
```

### `create-table` — Create a table in a base

```bash
uv run airtable_cli.py create-table appXXX \
    --name "New Table" \
    --fields '[{"name":"Name","type":"singleLineText"}]'
```

### `update-table` — Rename or re-describe a table

```bash
uv run airtable_cli.py update-table appXXX tblXXX --name "Renamed"
```

### `create-field` — Add a field to a table

```bash
uv run airtable_cli.py create-field appXXX tblXXX \
    --name "Status" --type singleSelect \
    --options '{"choices":[{"name":"Todo"},{"name":"Done"}]}'
```

| Flag | Description |
|------|-------------|
| `--name NAME` | Field name (required) |
| `--type TYPE` | Airtable field type (e.g. `singleLineText`, `number`, `singleSelect`) (required) |
| `--description TEXT` | Optional human-readable description |
| `--options JSON` | Type-specific options (e.g. choices for `singleSelect`) |

### `update-field` — Rename or re-describe a field

```bash
uv run airtable_cli.py update-field appXXX tblXXX fldXXX --name "State"
```

---

## Auth notes

- See **First-time setup** at the top of this document for the one-time OAuth flow.
- Tokens are short-lived (~1 hour). The script checks expiry before each run and
  refreshes silently when needed.
- Cache location: `~/.cache/rbx-skills/airtable/token_cache.json` (mode 0600).
  Delete this file to force a full re-auth.

## Error codes

| Code | Meaning |
|------|---------|
| 401 | Token expired — script auto-refreshes once and retries |
| 403 | Insufficient Airtable permissions for the requested operation |
| 404 | Resource not found |
| 422 | Invalid payload (bad field name, type mismatch, malformed JSON) |
| 429 | Rate limited — script waits `Retry-After` (max 60s) and retries once |
