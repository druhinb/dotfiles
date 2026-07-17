# Channels

Interact with channels through Engine Portal.

## Available Commands

```bash
# List all channels (--public-only is optional)
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py list --public-only

# Get a specific channel by name
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py get "channel-name"

# List versions for a channel on a given platform (--page-size and --page-token are optional)
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py list-versions "channel-name" "platform" --page-size 20 --page-token "abc"

# Get channel enrollment status for a Roblox username
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py user-status "roblox-username"

# List Android engine binary build jobs for a channel
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py build-jobs "channel-name"

# List Android binary deployments for a channel
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py android-binary-deployments "channel-name"

# Get fast flag overrides for a channel — flag values that differ from defaults on that channel.
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py channel-flags "channel-name"

# List user bindings for a channel, one row per platform — which users are bound to which platforms.
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py channel-bindings "channel-name"

# List public channels a given Roblox username is enrolled in.
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py user-enrollments "roblox-username"

# Get channel bindings for a given Roblox username, one row per platform. Inverse of channel-bindings.
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py user-bindings "roblox-username"

# List users publicly enrolled in a specific channel.
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py public-enrollments "channel-name"

# List all enrollment requests across every channel — a global view.
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py all-enrollment-requests

# List enrollment requests scoped to a single channel.
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py enrollment-requests "channel-name"

# Get live release branch versions with branch and platform status — what version is live per platform.
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py release-versions

# List enrollment gate checks for all branches of a channel, deduplicated by check type.
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py enrollment-checks "channel-name"

# Get enrollment request thresholds — limits/caps governing how many enrollment requests are allowed.
uv run ${CLAUDE_SKILL_DIR}/scripts/channels_api.py enrollment-thresholds
```

## Understanding Channels

Engine Channels are a way to test custom engine binaries and/or 
flag overrides/setups in a production environment without fully releasing them to 
everyone. They support both private testing and public testing, and are meant 
for workflows like validating a WIP engine change, testing a flagged/unflagged 
behavior, or running pre-release verification.  

A good mental model is: “a named test bucket for engine runtime behavior.” 
A channel represents a specific engine configuration that users or testers 
can be routed onto. That routing can happen either by binding specific Roblox 
accounts to the channel for private testing, or by public enrollment that 
sends some percentage of production users onto the channel.

Each channel has the following fields:

| Field | Description |
|---|---|
| `name` | Unique channel identifier |
| `owner` | AD email of the channel owner |
| `createdBy` | AD email of whoever created the channel (may differ from owner) |
| `isFlagOnly` | If `true`, the channel only carries flag overrides and does not deliver a binary |
| `isArchived` | If `true`, the channel is no longer active |
| `createdAt` / `updatedAt` | Unix timestamps |
| `platforms` | Platforms the channel targets (e.g. `WindowsPlayer`, `MacStudio`, `IOSApp`) |
| `features.controlChannelFeatureType` | Whether this channel acts as a control channel |
| `features.androidBinaryFeatureType` | Android binary delivery capability |
| `controlChannel` | Name of the associated control channel, if any |
