---
name: agent-access-request
description: Help a user request additional network or tool access for their agent sandbox. Use this skill when someone says their agent can't reach a URL, needs an MCP server enabled, wants to add a skill, or asks "how do I get access to X for my agent". Always use this skill rather than trying to work around the sandbox restriction directly — the right answer is to request the access formally so the security and network teams can review and enable it.
---

# Agent Access Request

Generate a structured access request document for the security and network teams to review, approve, and enable additional access for an agent sandbox.

Agents run in isolated environments with restricted network access by default. Any outbound connections, MCP servers, or skills that fall outside the default allowlist require a formal request. This skill collects the necessary information and produces a markdown document the requester can paste into their team's review system (GitHub issue, Jira ticket, Slack thread, etc.).

---

## Interview

Work through the following steps in order. Ask multiple related questions together to avoid unnecessary back-and-forth, but don't skip any field — all of it is needed by the reviewers.

### Step 1 — Requester

Auto-detect — do not ask the user:

- **Name**: `git config user.name`
- **Email**: `git config user.email`
- **Team / org**: Ask the user — no reliable auto-detection available.

### Step 2 — Agent overview

Auto-detect — do not ask the user:

- **Harness / framework**: Ask the user — no reliable auto-detection available.
- **Running environment**: Detect from the environment:
  - `$CODER_WORKSPACE_ID` is set → "devspace"
  - `$CI` or `$GITHUB_ACTIONS` is set → "CI runner"
  - macOS (`uname` returns `Darwin`) → "local laptop (macOS)"
  - Linux, no CI vars → "local laptop (Linux)"
  - Fall back to asking only if none of the above match.

### Step 3 — Requested access

Start by asking: *"What service or domain(s) do you need access to, and will your agent connect to it via MCP?"*

Then collect:

- **application_endpoint**: the application name and/or URL/hostname being accessed
- **datastore** (if applicable): ask for instance/cluster, database(s)/table(s), and access mode (read/write/both) if the service is a data store (e.g. Redshift, Clickhouse, Hive, BigQuery, Snowflake, S3, RDS, DynamoDB)
- **mcp** (if applicable): hosting type, launch command (if sandbox), and URL/transport

**MCP — ask three follow-up questions whenever MCP is mentioned:**

1. *"Is the agent using MCP as the transport to reach this service?"* — If yes, record the service endpoint in Network Endpoints as usual; MCP is just the protocol, not a separate entry.
2. *"Are you deploying your own MCP server?"* — Only capture a row in the MCP Servers section if the answer is yes.
3. *"Where will that MCP server run?"* — Capture one of: **sandbox** (co-located with the agent), **vendor-hosted** (external SaaS), or **internal** (deployed within Roblox infrastructure).
4. If **sandbox**: *"What command is used to launch the MCP server?"* — Capture the full command (e.g. `npx @modelcontextprotocol/server-filesystem /data`).

Each access item should be submitted as a separate request. If the user mentions multiple items, complete one request at a time and offer to start a new one when done.

### Step 4 — Justification

Collect:

- What business workflow does this access support?

### Step 5 — Risk and data sensitivity

Collect:

- What data flows through these connections?
- Blast radius: if this access were compromised or misused, what is the worst-case impact?
- Duration: is this permanent, or temporary until a specific milestone or date?

**Data classification**: Using the DCL table in `[assets/data_classification.md](assets/data_classification.md)`, propose the most appropriate classification level based on the data described. Explain your reasoning briefly, then ask the user to confirm or correct it.

---

## Output

Once all information is collected, fill in `[assets/request-template.json](assets/request-template.json)` with the collected values. Always include all keys from the template. Set non-applicable fields to `""`. Serialize as compact JSON (no whitespace), then encode with: `echo -n '<json>' | base64`

Output the base64 string, then tell the user: *"Submit the above at **go/agenttoolrequest**."*