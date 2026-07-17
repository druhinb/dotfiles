# TestHub

Interact with TestHub through Engine Portal.

## Available Commands

```bash
# List all supported platforms
uv run $CLAUDE_SKILL_DIR/scripts/testhub_api.py platforms

# List all available test types
uv run $CLAUDE_SKILL_DIR/scripts/testhub_api.py test-types

# List all devices (--platform is optional, filters by platform code name)
uv run $CLAUDE_SKILL_DIR/scripts/testhub_api.py devices --platform "platform-codename"

# List test definitions (all filters are optional)
uv run $CLAUDE_SKILL_DIR/scripts/testhub_api.py list-tests \
  [--test-type "codename"] [--owner "username"] [--platform "codename"] \
  [--page 1] [--limit 25]

# Get a single test definition by code name
uv run $CLAUDE_SKILL_DIR/scripts/testhub_api.py get-test "test-codename"

# List test runs (all filters are optional; multi-value filters accept multiple space-separated values)
# Note: broad filters like --platform used alone may return 500 errors due to query timeouts.
# If this happens, add more filters (e.g. --requester, --test, --status) to narrow the result set.
uv run $CLAUDE_SKILL_DIR/scripts/testhub_api.py list-runs \
  [--test-type TYPE1 TYPE2] [--suite SUITE1] [--test TEST1 TEST2] \
  [--platform PLATFORM1] [--device DEVICE1] \
  [--status Pending Running Success Failed Timeout Indeterminate Skipped] \
  [--owners OWNER1 OWNER2] [--requester REQ1] [--initiator Local CLI] \
  [--source SOURCE1] [--from "2024-01-01T00:00:00Z"] [--to "2024-12-31T23:59:59Z"] \
  [--group-tests] [--test-name "substring"] [--page 1] [--limit 25] [--sort "field"]

# Get a single test run by ID
uv run $CLAUDE_SKILL_DIR/scripts/testhub_api.py get-run "run-id"

# List device runs (all filters are optional)
uv run $CLAUDE_SKILL_DIR/scripts/testhub_api.py list-device-runs \
  [--test-type "codename"] [--test "codename"] [--platform "codename"] \
  [--device "codename"] [--status Pending|Running|Success|Failed|Timeout|Indeterminate|Skipped] \
  [--suite "codename"] [--page 1] [--limit 25]

# Get a single device run by ID
uv run $CLAUDE_SKILL_DIR/scripts/testhub_api.py get-device-run "device-run-id"

# Get a single group run by ID
uv run $CLAUDE_SKILL_DIR/scripts/testhub_api.py get-group-run "group-run-id"

# Get a single suite run by ID
uv run $CLAUDE_SKILL_DIR/scripts/testhub_api.py get-suite-run "suite-run-id"
```

## Understanding TestHub

TestHub is a service for tracking and querying automated test runs across Roblox platforms and devices.

### Data Model

**Platforms & Devices** — A platform (e.g. Windows, iOS, Android) is a broad target; a device is a specific hardware configuration within that platform, carrying GPU, CPU, memory, and arch details. Use `platforms` and `devices` to discover valid code names for filtering.

**Test Types** — Categories of tests (e.g. integration, performance). Each type has a `codeName`, an enabled state, and a list of owners.

**Test Definitions** — A test (`/tests`) defines what is being tested: its code name, associated test type, supported platforms, health state, owners, and PagerDuty ID. Use `list-tests` to browse and `get-test` to inspect a single definition.

**Run Hierarchy** — Runs are nested:
- A **group run** (`get-group-run`) groups multiple test runs together.
- A **suite run** (`get-suite-run`) scopes runs to a named suite.
- A **test run** (`list-runs` / `get-run`) is a single test execution, which contains one or more device runs.
- A **device run** (`list-device-runs` / `get-device-run`) is the leaf — one test on one device, with attachments, screenshots, metrics, and device settings.

**Run Status** — All run types share the same status enum: `Pending`, `Running`, `Success`, `Failed`, `Timeout`, `Indeterminate`, `Skipped`.

**Test Health** — Embedded on tests and runs: `Healthy`, `Failing`, or `Flaky`, linked to a Jira key and an open/closed/resolved status.

**Child Run Counts** — Runs with children (group, suite, test) include a `total` object with per-status breakdowns: `{ count, pending, running, success, failed, timeout, indeterminate, skipped }`.

---

## Screenshots

Device runs for visual/rendering tests include screenshot URLs (`url`), diff images (`diffUrl`), and reference baselines (`reference.url`). These are presigned CloudFront URLs and are short-lived.

When a user asks to see screenshots or analyze test results that include screenshots, ask whether they'd prefer to:
1. **Open the links themselves** — share the URLs so they can open them in a browser
2. **Have you download and analyze them** — confirm with the user where they'd like the files saved (default: `/tmp`), as environment restrictions may affect where files can be written or opened

Do not download screenshots automatically without asking first.

---

## Response Shapes

### `platforms`
```
{ platforms: [{ id, name, codeName }] }
```

### `test-types`
```
{ types: [{ id, name, codeName, enabled: bool, owners: string[] }] }
```

### `devices`
```
{ devices: [{ id, name, codeName, platform?: { id, name, codeName },
              gpuName, cpuName, cpuArch, cpuCores: int, cpuMemory: int }] }
```

### `list-tests` / `get-test`
```
{ tests: [Test], total: int }

Test: {
  id, name, codeName,
  testType?: { codeName, name },
  platforms: [{ id, name, codeName }],
  health?: TestHealth | null,
  enabled: bool, owners: string[], pagerdutyId: int
}
```

### `list-runs` / `get-run`
```
{ runs: [TestRun], total: int }

TestRun: RunBase + {
  codeName, name, owners: string[],
  testType?: { codeName, name },
  health?: TestHealth | null,
  devices: [DeviceRun],        -- null in list results, populated in get-run
  total?: ChildRunCount
}
```

### `list-device-runs` / `get-device-run`
```
{ runs: [DeviceRun], total: int }

DeviceRun: RunBase + {
  codeName, name,
  device?: { id, codeName, name },
  platform?: { codeName, name },
  health?: TestHealth | null,
  settings?: DeviceRunSettings,
  attachments: [{ name, url }],   -- presigned CloudFront URLs, short-lived
  screenshots: [{ url, diffUrl, reference? }],
  metrics: [{ [key]: string }]
}
```
Note: requires at least one filter — a bare call returns 500.

### `get-group-run` / `get-suite-run`
```
GroupRun:  RunBase + { name,     tests: [TestRun], total?: ChildRunCount }
SuiteRun:  RunBase + { codeName, name, tests: [TestRun], total?: ChildRunCount }
```

### Shared: `RunBase`
```
{ id, createdAt: unix_ts, startTime: unix_ts, updatedAt: unix_ts,
  duration?: int,
  status: "Pending"|"Running"|"Success"|"Failed"|"Timeout"|"Indeterminate"|"Skipped",
  runType: "Test"|"Suite"|"Group"|"Device"|"Mixed",
  initiator: "Local"|"CLI",
  requester: string, source: string,
  parent: { group?, suite?, test?, references: [] } }
```
Note: `startTime` of `-62135596800` means the run has not yet started (.NET default DateTime serialized as Unix timestamp).

### Shared: `TestHealth`
```
{ id, jiraKey,
  state: "Healthy"|"Failing"|"Flaky",
  status: "Open"|"Closed"|"Resolved",
  initiator, requester, device?, platform?, createdAt, updatedAt }
```

### Shared: `ChildRunCount`
```
{ count, pending, running, success, failed, timeout, indeterminate, skipped }
```

### Shared: `DeviceRunSettings`
```
{ id, deviceId, deviceRunId, placeId, placeVersion,
  quality, frmQuality, featureLevel, shadingLang,
  screenWidth, screenHeight, createdAt, updatedAt }
```
