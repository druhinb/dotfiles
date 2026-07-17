# Fast Flags

Interact with fast flags through Engine Portal.

## Available Commands

```bash
# Get the production status across all platforms and versions
uv run ${CLAUDE_SKILL_DIR}/scripts/flags_api.py status

# Check if a specific flag exists in a given version
uv run ${CLAUDE_SKILL_DIR}/scripts/flags_api.py status --type "Flag Type" --name "Flag Name" --major "Major Version Number" --minor "Minor Version Number"

# Get the details of a flag
uv run ${CLAUDE_SKILL_DIR}/scripts/flags_api.py details "Flag Type" "Flag Name"

# Get the value of a flag for the specific buckets
uv run ${CLAUDE_SKILL_DIR}/scripts/flags_api.py value "Flag Type" "Flag Name" "Bucket 1" "Bucket 2" ...

# Get the number and names of the flags for a given user
uv run ${CLAUDE_SKILL_DIR}/scripts/flags_api.py mine "AD Username" -l "Optional: list the names of the flags"

# Get the lock status of engine flags to tell if they can be flipped
uv run ${CLAUDE_SKILL_DIR}/scripts/flags_api.py lock-status

# Get the available buckets and their configuration
uv run ${CLAUDE_SKILL_DIR}/scripts/flags_api.py buckets

# Get the bucket status for a specific flag
uv run ${CLAUDE_SKILL_DIR}/scripts/flags_api.py buckets --type "Flag Type" --name "Flag Name"

# List flag change requests (all filters are optional)
uv run ${CLAUDE_SKILL_DIR}/scripts/flags_api.py requests \
  [--author "AD Username"] \
  [--bucket "Bucket Name"] \
  [--flag-name "FlagName"] \
  [--flag-type "regularFlags"|"rolloutFlags"|"stagedFlags"|"universeFilterFlags"|"placeFilterFlags"|"dataCenterFilterFlags"|"ixpFlags"] \
  [--from "2024-01-01T00:00:00Z"] \
  [--to "2024-12-31T23:59:59Z"] \
  [--owner "AD Username"] \
  [--per-page 25] \
  [--cursor "pagination_cursor"]

# Get a specific flag change request by ID.
# requestId is the GitHub PR number of the request. The default requests command returns this for each request.
uv run ${CLAUDE_SKILL_DIR}/scripts/flags_api.py requests "requestId"
```

## Flag Types

All commands that accept a flag require both a type and a name as separate arguments. Valid types are:

`FFlag`, `DFFlag`, `SFFlag`, `FInt`, `DFInt`, `SFInt`, `FString`, `DFString`, `SFString`, `FLog`, `DFLog`, `SFLog`

**Identifying flags in source code**: Flags are defined via macros in C++ and Lua source.
The macro name determines the flag type and the first argument is the flag name.
Map macros to their flag type using the table below before querying via `flags_api.py`:

| Flag Type | C++ Macro                       | Lua Macro             |
| --------- | ------------------------------- | --------------------- |
| FFlag     | FASTFLAGVARIABLE                | Game:DefineFastFlag   |
| FInt      | FASTINTVARIABLE                 | Game:DefineFastInt    |
| FString   | FASTSTRINGVARIABLE              | Game:DefineFastString |
| FLog      | LOGVARIABLE                     | N/A                   |
| DFFlag    | DYNAMIC_FASTFLAGVARIABLE        | N/A                   |
| DFInt     | DYNAMIC_FASTINTVARIABLE         | N/A                   |
| DFString  | DYNAMIC_FASTSTRINGVARIABLE      | N/A                   |
| DFLog     | DYNAMIC_LOGVARIABLE             | N/A                   |
| SFFlag    | SYNCHRONIZED_FASTFLAGVARIABLE   | N/A                   |
| SFString  | SYNCHRONIZED_FASTSTRINGVARIABLE | N/A                   |

For example, `FASTFLAGVARIABLE(MyEngineFlag, false)` defines an `FFlag` named `MyEngineFlag` —
query it with `flags_api.py details FFlag MyEngineFlag`.

All commands accept the type and name as separate arguments. Do not combine them into a
single string like `FFlagMyEngineFlag`. If the user provides a combined string, split it
into type and name using the types listed above.

## Understanding Flags
- Use the details command to get an overview of an individual flag — it is also the authoritative way to confirm a flag exists. If the flag does not exist the command will print an error and exit with code 1. Other commands (e.g. `buckets`, `value`) do not reliably indicate non-existence, so always run `details` first if existence is in doubt.
- Use the flag buckets table to map bucket groups to individual buckets. More 
specific bucket names override the top level bucket group value if they are set.
- The status command will tell you which platforms exist and if the flag exists 
in the current version of each one.
- The buckets command will tell you which buckets the flag can set values for.
- To be flippable, a flag must be available for the given bucket and the flag
lock status must either be unlocked or overridable. In the case that the lock
status allows overrides the user will have to submit a PCM ticket.
- Flag requests flip the value of a flag for one or more buckets.
- Each platform reads the value for flags from the most specific bucket where it
is defined.

**Common Mistakes**:
- Version numbers for platforms have different formats. 2.717.982 would have major version 717 and minor 0982.
0.719.0.7191339 uses the last segment broken into major and minor by taking the first three digits for major and last four for minor.

## Flag Buckets:
- Buckets 
| Bucket Group | Bucket Names |
|--------------|--------------|
| `Common`       | `Common` |
| `RCC`          | `CommonRcc`, `GamesRCC`, `LinuxRCCThumbnailer` |
| `Platform`     | `CommonMac`, `CommonWindows` |
| `Client`       | `WindowsClient`, `MacClient`, `AndroidClient`, `Google`, `Amazon`, `QuestVR`, `iOSClient`, `UWPClient`, `XBoxClient`, `PlayStation`, `TestClient` |
| `Thumbnailer`  | `LinuxRCCThumbnailer` |
| `Studio`       | `Studio`, `WindowsStudio`, `MacStudio` |
| `Bootstrapper` | `CommonBootstrapper`, `PCBootstrapper`, `MacBootstrapper`, `PCPlayerBootstrapper`, `MacPlayerBootstrapper`, `PCStudioBootstrapper`, `MacStudioBootstrapper` |
| `CJV / Luobu`  | `CommonCJV`, `AndroidCJV`, `iOSCJV`, `CJVRCC`, `StudioCJV`, `PCBootstrapperCJV`, `MacBootstrapperCJV` |
