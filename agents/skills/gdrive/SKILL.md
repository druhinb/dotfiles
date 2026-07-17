---
name: gdrive
description: >
  Google Drive access — read and write. Use this skill whenever the user wants to
  interact with Google Drive: search, download, export, create, or update files.
  Triggers on phrases like "find that doc in Drive", "download the spreadsheet",
  "create a doc", "write to Drive", or "list my Drive files".
  All operations use the gdrive MCP server (read and write to any folder,
  external sharing blocked), including formatting-preserving edits via
  apply_doc_edits and structure inspection via get_doc_structure.
  Note: first use requires a one-time browser OAuth; if the script prints an
  "ACTION REQUIRED" URL, show it to the user and ask them to open it in a browser
  before retrying.
---

# Google Drive

All Google Drive operations (read and write) go through the `gdrive` MCP server,
which proxies to the Roblox mcp-gateway. There is no folder restriction — the agent can
access any file the user's OAuth token can reach.

> **Do NOT use curl or the Drive API directly — it will be blocked by the egress gateway.**
> All operations MUST go through the `gdrive` MCP server tools below.

## Security

- **External sharing blocked:** Files shared outside the Roblox organization (`roblox.com`)
  are blocked from reads and writes. Any file with permissions granted to non-`@roblox.com`
  users, external domains, or "anyone" link sharing will be rejected.
- **DLP Restricted label:** Files tagged with EntSec's "Restricted" sensitivity label are
  blocked from MCP access.
- **OAuth token validation:** Tokens must be issued by the expected Google Client ID with
  scopes within the allowlist.

## Setup (one-time)

Register the `gdrive` MCP server. This is a one-time step per environment:

1. Run `/mcp-adaptor` and select `gdrive`
2. Restart your Claude session (quit and reopen) so the new MCP tools load
3. On first use you'll be prompted with a browser OAuth URL — open it and approve access

After this, all read and write tools will be available in all future sessions. If you do
not see these tools, re-run `/mcp-adaptor` — do not attempt to access the Drive API via
curl (it will be blocked).

## Available tools

Once registered, the following MCP tools are available:

| Tool | Description |
|------|-------------|
| `list_files` | List or search files in Google Drive |
| `get_file_metadata` | Get metadata for a specific file by ID |
| `get_file` | Read the text content of a file (Docs as text, Sheets as CSV) |
| `create_document` | Create a new Google Doc in a specified folder |
| `update_document` | Replace the full text content of a file (wipes all formatting) |
| `get_doc_structure` | Read a Doc's heading anchors + content ranges (slim, LLM-friendly) |
| `apply_doc_edits` | Apply formatting-preserving edits (`replace_all_text` / `insert_text` / `delete_content_range`) in one batchUpdate |
| `insert_inline_images` | Insert inline images into a Doc at specified content indices |

## Typical usage

### 1. Search for files

```
Use list_files with:
- query: "name contains 'design doc'"
- page_size: 10
```

### 2. Read a file

```
Use get_file with:
- file_id: "<the file ID from list_files or a URL>"
```

Google Docs → plain text, Sheets → CSV, other files → raw content.

### 3. Create a document

```
Use create_document with:
- title: "My Document Title"
- folder_id: "<the folder ID where the doc should live>"
- content: "Initial text content"
- content_type: "text/plain" or "text/markdown"
```

The agent can resolve folder names to IDs using `list_files` with a query like
`mimeType='application/vnd.google-apps.folder' and name='MyFolder'`.

### 4. Update a document (full replace)

`update_document` replaces the entire body in one shot. It is the simplest update path,
but it **wipes all formatting** — paragraph styles, table layouts, inline images, and
comments. For a doc with styling worth keeping, prefer `apply_doc_edits` (below).

```
Use update_document with:
- file_id: "<the document's file ID>"
- content: "New full text content (replaces existing content)"
```

### 5. Surgical edits that preserve formatting

`apply_doc_edits` submits one or more edits in a single Docs `batchUpdate`, leaving the
surrounding styles untouched. Each edit is exactly one of:

- `replace_all_text { find, replace, match_case? }` — replace every occurrence of an exact
  string (case-insensitive unless `match_case` is true). The replacement inherits the
  formatting at the matched text's start. Best for surgical content updates (price changes,
  version bumps, paragraph swaps) that should leave the surrounding styles untouched.
- `insert_text { index, text }` — insert text at a 1-based content index; inherits formatting
  from the surrounding text run.
- `delete_content_range { start_index, end_index }` — delete content in `[start_index, end_index)`.
  Use sparingly: deleting an entire structural element clears its formatting.

Index-mutating edits (`insert_text`, `delete_content_range`) are reordered server-side
highest-index-first, so you can pass indices observed in the current document state.
`replace_all_text` edits are order-independent and applied last. Cap of 100 edits per call.

```
Use apply_doc_edits with:
- file_id: "<doc id>"
- edits:
  - { replace_all_text: { find: "$9.99", replace: "$11.99" } }
  - { replace_all_text: { find: "Status: Draft v2", replace: "Status: Draft v3" } }
```

To rewrite a specific section without touching the rest, call `get_doc_structure` first to
find that section's heading range, then build edits that operate within it.

### 6. Inspect a doc's structure (to plan edits)

`get_doc_structure` returns the doc's title, total `end_index`, and a list of heading
paragraphs (`TITLE`, `SUBTITLE`, `HEADING_1`..`HEADING_6`) with their text and 1-based
content ranges. Pair it with `apply_doc_edits` to target a section precisely.

```
Use get_doc_structure with:
- file_id: "<doc id>"
```

The response is intentionally slim — per-character formatting and inline-object payloads are
omitted to fit LLM context budgets. For full document text, use `get_file`.

## Troubleshooting

**`list_files` returns empty even though files exist:**
Your OAuth token may predate the current scope set. To fix: go to
https://apis.simulprod.com/credential-broker/v1/connect/gdrive, revoke and
re-authorize. This forces a new token with all current scopes. After re-auth, restart
your Claude session.

**"access denied: file is shared externally":**
The file has sharing permissions that extend outside `roblox.com`. The agent cannot
read or write files shared with external users or via "anyone with the link" sharing.

**"access denied: file carries the Restricted sensitivity label":**
The file has been tagged by EntSec's DLP rule. This file cannot be accessed through MCP.

## Things to know

- **No folder restriction:** The agent can access any file the user has access to via their
  OAuth token — no pre-approved folder list required.
- **External sharing blocked:** Files shared outside `roblox.com` are blocked from all operations.
- **Full replacement:** `update_document` replaces the entire document content. Use
  `apply_doc_edits` for surgical edits that preserve formatting.
- **Google Docs only:** `create_document` creates Google Docs. It cannot create folders or
  other file types. To create folders, use the Google Drive web UI.

## Legacy CLI (removed — no longer functional)

The previous `gdrive_cli.py` script is **no longer functional** and is kept only until it
is deleted. It authenticated against the credential-broker `google_workspace` service,
which has been removed; the consolidated `gdrive` service is gateway-only and does not
issue direct CLI tokens. Do not use it — all reads and writes go through the MCP tools
above.
