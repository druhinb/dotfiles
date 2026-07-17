# Insights

Query Portal Insights for Jira issues, bugs, fast flags, and other tracked items.

## Available Commands

```bash
# Query using a named query ID (see Named Query IDs below)
uv run $CLAUDE_SKILL_DIR/scripts/insights_api.py query --query-id "p0-bugs"

# Scope a named query to a specific person (issues where they are the DRI)
uv run $CLAUDE_SKILL_DIR/scripts/insights_api.py query --query-id "flaky-tests" --person 14482

# Scope a named query to a person's org (their DRI issues + all sub-reports)
uv run $CLAUDE_SKILL_DIR/scripts/insights_api.py query --query-id "stale-flags-180" --manager 11364

# Scope a named query to an org entity (include is a JSON array of {name, value} objects — see Include Values below)
uv run $CLAUDE_SKILL_DIR/scripts/insights_api.py query --query-id "p0-bugs" --include '[{"name": "team", "value": 123}]'

# Query with a fully custom filter scoped to a user by ROS ID (repeatable)
uv run $CLAUDE_SKILL_DIR/scripts/insights_api.py query --filter '{"open": true, "priorities": ["P0", "P1"]}' --dri 14482

# Combine a custom filter with additional flags (merged before sending)
uv run $CLAUDE_SKILL_DIR/scripts/insights_api.py query --filter '{"issueTypes": ["Bug"]}' --dri 14482 --assignee 16192

# Query with a fully custom filter (no user scoping)
uv run $CLAUDE_SKILL_DIR/scripts/insights_api.py query --filter '{"open": true, "priorities": ["P0", "P1"], "teamIds": [123]}'

# Paginate results (--page-size and --page-number are optional, page-number is 0-indexed)
uv run $CLAUDE_SKILL_DIR/scripts/insights_api.py query --query-id "priority-bugs" --page-size 25 --page-number 0

# Sort results (--sort-column and --sort-direction are optional)
uv run $CLAUDE_SKILL_DIR/scripts/insights_api.py query --query-id "p1-bugs" --sort-column "created_time" --sort-direction desc

# Scope by date range (ISO 8601 timestamps, both optional)
uv run $CLAUDE_SKILL_DIR/scripts/insights_api.py query --query-id "p0-bugs" --start-date "2024-01-01T00:00:00Z" --end-date "2024-12-31T23:59:59Z"

# List all available named query IDs
uv run $CLAUDE_SKILL_DIR/scripts/insights_api.py list-queries
```

> **Named query + user scoping:** Use `--person` or `--manager` to scope a named query to a user — the API does not allow `--query-id` and `--filter` together. Use `--dri`/`--assignee` only with custom `--filter` (no `--query-id`).

## Understanding Insights

Portal Insights is a query layer over Jira issues that provides structured, filterable access to bugs, fast flags, and other tracked items. It supports both pre-built named queries and fully custom filters, and can scope results to org entities (groups, teams, pods).

### Named Query IDs

Pass one of these strings as `--query-id`. The service resolves it to a pre-built filter configuration.

**Bug Queries**
| ID | Description |
|----|-------------|
| `unassigned-bugs` | Open, unassigned bugs |
| `untriaged-bugs` | Bugs with status `Submitted` |
| `p0-bugs` | Open bugs with priority P0 |
| `p1-bugs` | Open bugs with priority P1 |
| `p2-bugs` | Open bugs with priority P2 |
| `p3-bugs` | Open bugs with priority P3 |
| `p4-bugs` | Open bugs with priority P4 |

**DFB Queries** (label `DFB-DoNotRemove`, excludes `DFBTEST` project)
| ID | Description |
|----|-------------|
| `dfb-p0` | Open DFB issues at P0 |
| `dfb-p1` | Open DFB issues at P1 |
| `dfb-p2` | Open DFB issues at P2 |
| `dfb-p3` | Open DFB issues at P3 |
| `dfb-p4` | Open DFB issues at P4 |

**Test Queries**
| ID | Description |
|----|-------------|
| `flaky-tests` | Issues labeled `excludedTest`, not `TestsQuarantined`, not closed/verified |
| `tests-excluded` | Same filter as `flaky-tests` |

**Stale Fast Flag Queries** (Boolean flags only, no labels)
| ID | Description |
|----|-------------|
| `stale-flags-60` | Boolean flags not flipped in 60+ days |
| `stale-flags-180` | Boolean flags not flipped in 180+ days |
| `stale-flags-1year` | Boolean flags not flipped in 1+ year |

**Other Queries**
| ID | Description |
|----|-------------|
| `vulnerability` | Open issues labeled `vulnerability` |
| `campaign-test` | Open issues labeled `Campaign-RBXASSERT` |
| `campaign-rbxassert` | Open issues labeled `RbxAssert` |
| `campaign-metriccleanup` | Open issues labeled `metriccleanup` |
| `campaign-dmct` | Open issues labeled `dmct-conversion` |

**Composite Query IDs** (combine multiple sub-queries, return merged results)
| ID | Sub-queries |
|----|-------------|
| `dfb-bugs` | `dfb-p0`, `dfb-p1`, `dfb-p2`, `dfb-p3`, `dfb-p4` |
| `priority-bugs` | `p0-bugs`, `p1-bugs`, `p2-bugs`, `p3-bugs`, `p4-bugs` |
| `flaky-test-unassigned-bugs` | `flaky-tests`, `unassigned-bugs` |

### Include Values (`--include` JSON array)

`--include` scopes a named query to an org entity or user. Each element is `{"name": "<type>", "value": <ROS integer ID>}`. All values are ROS IDs.

| Name | Description |
|------|-------------|
| `group` | Scope to a group |
| `team` | Scope to a team |
| `pod` | Scope to a pod |
| `manager` | Issues where the DRI is the given person or any of their sub-reports (recursive) |
| `person` | Issues where the given person is the DRI themselves |

> **Scoping to a single user:** Use `person` by default. Use `manager` only when the user asks for issues across the person's org, team, or pod (i.e. their sub-reports are included).

### Filter Fields (`--filter` JSON object)

All fields are optional and must be sent as camelCase. String list filters include only matching issues; excluded string lists remove matches.

**Boolean flags**
| Field | Description |
|-------|-------------|
| `open` | Whether the issue is open |
| `assigned` | Whether the issue has an assignee |
| `resolved` | Whether the issue has a resolution date |
| `noLabels` | Whether the issue has no labels |
| `closedIssuesOnly` | ResolutionDate != null OR Status == "Closed" |
| `slaAtRisk` | Open issues within 7 days of their priority SLA |
| `slaBreached` | Open issues that have exceeded their priority SLA |
| `resolutionInSla` | For closed issues: resolution time was within `slaDays` |

**Date filters**
| Field | Description |
|-------|-------------|
| `createdBeforeTime` | Upper bound on creation date |
| `createdAfterTime` | Lower bound on creation date |
| `resolvedBeforeTime` | Upper bound on resolution date (exclusive) |
| `resolvedAfterTime` | Lower bound on resolution date |

**String list filters (include)**
| Field | Description |
|-------|-------------|
| `statuses` | Statuses to include (e.g. `["Submitted"]`) |
| `labels` | Labels to include (e.g. `["vulnerability"]`) |
| `issueTypes` | Issue types to include (e.g. `["Bug", "Fast Flag"]`) |
| `priorities` | Priorities to include (e.g. `["P0", "P1"]`) |
| `projectKeys` | Jira project keys to include |

**String list filters (exclude)**
| Field | Description |
|-------|-------------|
| `excludedStatuses` | Statuses to exclude (e.g. `["Verified", "Closed", "Done"]`) |
| `excludedLabels` | Labels to exclude |
| `excludedProjectKeys` | Jira project keys to exclude (e.g. `["DFBTEST"]`) |

**Org scoping (integer lists)**
| Field | Description |
|-------|-------------|
| `groupIds` | Filter to specific group IDs |
| `teamIds` | Filter to specific team IDs |
| `podIds` | Filter to specific pod IDs |
| `managerIds` | Issues assigned under specific managers |
| `assigneeIds` | Specific assignee user IDs |
| `driIds` | Specific DRI user IDs |

> **Filtering by user:** When a user asks for issues assigned to them (or to a specific person), use `--person` (or `driIds` in a custom filter) by default unless they explicitly ask for assignee scoping. The insights dashboard uses DRI as its primary ownership field, so it gives the most accurate picture of a user's issues. The DRI for an issue is the first defined value in this order: assignee → component lead → project lead → reporter.
>
> The `--person`, `--manager`, `--dri`, and `--assignee` flags accept any identifier: a ROS integer ID, email address, Slack handle, or username — the script resolves them to ROS IDs automatically. If the user provides only a full name, ask them for one of these acceptable identifiers before running the query.

**Other**
| Field | Description |
|-------|-------------|
| `fastFlagType` | Fast flag type string (e.g. `"Boolean"`) |
| `slaDays` | SLA threshold in days, used with `resolutionInSla` (P0/P1=7, P2=28, P3=90) |

### Response Fields

Each issue in the response includes: `id`, `key` (Jira key, e.g. `ENG-123`), `summary`, `project_key`, `issue_type`, `status`, `priority`, `severity`, `assignee` (user ID), `reporter` (user ID), `dri` (user ID), `group_id`, `team_id`, `pod_id`, `open_age` (days since created), `update_age` (days since last updated), `created_time`, `updated_time`, `resolution_date_time`, and `query_id` (which sub-query matched, for composite queries).

The response also includes `total_count`, `page_number`, `page_size`, `total_pages`, `has_more`, and `jql` (the generated JQL for the query).
