---
name: pagerduty
description: >
  Read-only access to Roblox's PagerDuty instance (roblox.pagerduty.com) via the credential
  broker. Use this skill whenever the user wants to look up incidents, check who's on call,
  inspect escalation policies, explore services, list teams, or look up users in PagerDuty —
  even if they just say things like "who's on call", "what incidents are open", "check PD",
  or "look up the on-call rotation".
---

# PagerDuty Read-Only Access

You have read-only access to Roblox's PagerDuty instance via a CLI bundled with this skill.
Authentication is handled automatically — credentials are fetched from the credential broker
and cached; you never need to manage tokens manually.

## Prerequisites

### Network access

`api.pagerduty.com` must be on the egress proxy allowlist. If you get a Squid 403 / `ERR_ACCESS_DENIED`, ask the user to request access in **#claude-code** on Slack (domain: `api.pagerduty.com`, method: GET, path: `/*`), then retry.

### One-time OAuth setup

PagerDuty OAuth must be connected once per user via the credential broker. If the CLI exits with code 2 and prints an action-required message, ask the user to open the URL shown, approve access, and then re-run the command. This is a one-time setup.

## Quick start

```bash
# Who is on call for a specific service? (resolves service → policy → oncalls automatically)
uv run $SKILL_DIR/scripts/pd_cli.py oncalls --service-name "sapi-authorization"

# Who is on call right now (all services)?
uv run $SKILL_DIR/scripts/pd_cli.py oncalls

# All open incidents
uv run $SKILL_DIR/scripts/pd_cli.py incidents

# Services and their owning teams
uv run $SKILL_DIR/scripts/pd_cli.py services
```

`$SKILL_DIR` is set automatically by Claude Code to the directory containing this `SKILL.md` file.

---

## Incidents

### List incidents

```bash
uv run $SKILL_DIR/scripts/pd_cli.py incidents
```

**Flags:**

| Flag | Description |
|---|---|
| `--status triggered\|acknowledged\|resolved` | Filter by status (repeatable; default: triggered + acknowledged) |
| `--urgency high\|low` | Filter by urgency (repeatable) |
| `--service SERVICE_ID` | Filter by service ID (repeatable) |
| `--team TEAM_ID` | Filter by team ID (repeatable) |
| `--since ISO8601` | Start of date range |
| `--until ISO8601` | End of date range |
| `--include RESOURCE` | Sideload extra data: `services`, `teams`, `users` (repeatable) |
| `--limit N` | Max results (default: 25) |

**Example — high-urgency triggered incidents for a team:**

```bash
uv run $SKILL_DIR/scripts/pd_cli.py incidents \
  --status triggered --urgency high --team PTEAM01
```

### Get a single incident

```bash
uv run $SKILL_DIR/scripts/pd_cli.py incident INCIDENT_ID
```

### List alerts for an incident

```bash
uv run $SKILL_DIR/scripts/pd_cli.py incident-alerts INCIDENT_ID
```

### Show event log for an incident

```bash
uv run $SKILL_DIR/scripts/pd_cli.py incident-log INCIDENT_ID
```

---

## On-Call

### Who is currently on call

```bash
uv run $SKILL_DIR/scripts/pd_cli.py oncalls
```

**Flags:**

| Flag | Description |
|---|---|
| `--service-name NAME` | Resolve on-call by service name — no IDs needed (e.g. `"sapi-authorization"`) |
| `--schedule SCHEDULE_ID` | Filter to a specific schedule (repeatable) |
| `--policy POLICY_ID` | Filter to a specific escalation policy (repeatable) |
| `--since ISO8601` | Start of on-call window |
| `--until ISO8601` | End of on-call window |

**Example — who's on call for a service (by name):**

```bash
uv run $SKILL_DIR/scripts/pd_cli.py oncalls --service-name "sapi-authorization"
```

**Example — who's on call for a specific schedule:**

```bash
uv run $SKILL_DIR/scripts/pd_cli.py oncalls --schedule PSCHED01
```

---

## Schedules

### List all schedules

```bash
uv run $SKILL_DIR/scripts/pd_cli.py schedules
uv run $SKILL_DIR/scripts/pd_cli.py schedules --query "platform"
```

### Get a schedule with rendered rotation

```bash
uv run $SKILL_DIR/scripts/pd_cli.py schedule SCHEDULE_ID \
  --since 2026-04-13T00:00:00Z --until 2026-04-20T00:00:00Z
```

---

## Escalation Policies

### List escalation policies

```bash
uv run $SKILL_DIR/scripts/pd_cli.py escalation-policies
uv run $SKILL_DIR/scripts/pd_cli.py escalation-policies --team PTEAM01
uv run $SKILL_DIR/scripts/pd_cli.py escalation-policies --query "infra"
```

### Get a single escalation policy

```bash
uv run $SKILL_DIR/scripts/pd_cli.py escalation-policy POLICY_ID
```

---

## Services

### List services

```bash
uv run $SKILL_DIR/scripts/pd_cli.py services
uv run $SKILL_DIR/scripts/pd_cli.py services --query "auth"
uv run $SKILL_DIR/scripts/pd_cli.py services --team PTEAM01
```

**Flags:**

| Flag | Description |
|---|---|
| `--query NAME` | Filter by name substring |
| `--team TEAM_ID` | Filter by team ID (repeatable) |
| `--include RESOURCE` | Sideload: `escalation_policies`, `teams`, `integrations` (repeatable) |

### Get a single service

```bash
uv run $SKILL_DIR/scripts/pd_cli.py service SERVICE_ID
```

---

## Teams

### List teams

```bash
uv run $SKILL_DIR/scripts/pd_cli.py teams
uv run $SKILL_DIR/scripts/pd_cli.py teams --query "data"
```

### List members of a team

```bash
uv run $SKILL_DIR/scripts/pd_cli.py team-members TEAM_ID
```

---

## Users

### List users

```bash
uv run $SKILL_DIR/scripts/pd_cli.py users
uv run $SKILL_DIR/scripts/pd_cli.py users --query "jane.doe@roblox.com"
uv run $SKILL_DIR/scripts/pd_cli.py users --team PTEAM01
```

**Flags:**

| Flag | Description |
|---|---|
| `--query NAME_OR_EMAIL` | Filter by name or email substring |
| `--team TEAM_ID` | Filter by team ID (repeatable) |
| `--include RESOURCE` | Sideload: `contact_methods`, `notification_rules`, `teams` (repeatable) |

### Get a single user

```bash
uv run $SKILL_DIR/scripts/pd_cli.py user USER_ID
```

---

## Error handling

| Exit code | Meaning |
|---|---|
| 0 | Success |
| 1 | API or auth error (details on stderr) |
| 2 | PagerDuty OAuth not yet connected — see one-time setup above |

HTTP errors from the API are printed to stderr with the status code and message. On 401, the CLI automatically retries once with a fresh token before exiting.
