#!/usr/bin/env bash
# Legacy bash LCA token resolver for the MCP gateway.
# New helpers use get_token.py / rbx_skills_mcp_gateway.get_lca_token() so
# stale injected tokens can fall through to refreshed sources.
#
# Usage: get_token.sh [env]
#   env ∈ {st1, st2, st3, prod}; defaults to prod.
# Writes the raw token to stdout on success.
#
# Exit codes:
#   0 — token on stdout.
#   1 — unexpected runtime error (HTTP failure, malformed response, etc).
#   2 — ACTION REQUIRED: user needs to do a one-time setup step. The
#       stderr message is actionable ("install X", "connect Y", …).
#
# Legacy resolution order:
#   1. $MCP_GATEWAY_TOKEN env var (injected by declawd / sandbox templates).
#   2. ~/.agent-keys/mcp-gateway file (also injected; auto-refreshed).
#   3. coder external-auth GHE token → LCA ghe-exchange (devspace fallback).
set -u

TOKEN_FILE="$HOME/.agent-keys/mcp-gateway"

env="${1:-prod}"
case "$env" in
  st1|st2|st3|prod) ;;
  *) echo "get_token.sh: unknown env '$env' (expected st1|st2|st3|prod)" >&2; exit 1 ;;
esac

# ----------------------------------------------------------------------------
# Pre-injected token (env var, then file)
# ----------------------------------------------------------------------------
if [ -n "${MCP_GATEWAY_TOKEN:-}" ]; then
  printf '%s' "$MCP_GATEWAY_TOKEN"
  exit 0
fi

if [ -r "$TOKEN_FILE" ]; then
  token="$(tr -d '\r\n' < "$TOKEN_FILE")"
  if [ -n "$token" ]; then
    printf '%s' "$token"
    exit 0
  fi
fi

# ----------------------------------------------------------------------------
# Devspace fallback: coder GHE token → LCA exchange
# ----------------------------------------------------------------------------
missing=()
for dep in coder curl jq; do
  command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
done
if [ "${#missing[@]}" -gt 0 ]; then
  cat >&2 <<EOF
ACTION REQUIRED — missing tools: ${missing[*]}

No injected token was found (\$MCP_GATEWAY_TOKEN unset, $TOKEN_FILE
missing) and the devspace fallback needs: coder, curl, jq. Install the
missing ones with your package manager (e.g. 'brew install jq'). If
'coder' is missing you are probably not inside a devspace; set
\$MCP_GATEWAY_TOKEN or populate $TOKEN_FILE instead.
EOF
  exit 2
fi

coder_err="$(mktemp)"
trap 'rm -f "$coder_err"' EXIT
ghe="$(coder external-auth access-token github-enterprise 2>"$coder_err" || true)"
if [ -z "$ghe" ]; then
  case "$(cat "$coder_err")" in
    *CODER_AGENT_URL*)
      cat >&2 <<EOF
ACTION REQUIRED — not inside a coder workspace.

'coder external-auth access-token' requires \$CODER_AGENT_URL, which is
only set inside a coder workspace (devspace). From a local machine, either:
  - SSH into your devspace and run the command there, or
  - set \$MCP_GATEWAY_TOKEN (or populate $TOKEN_FILE) with an LCA token.

coder said: $(cat "$coder_err")
EOF
      ;;
    *)
      cat >&2 <<EOF
ACTION REQUIRED — GitHub Enterprise not connected in coder.

Run:   coder external-auth github-enterprise
Then re-run the original command.

coder said: $(cat "$coder_err")
EOF
      ;;
  esac
  exit 2
fi

body="$(curl -sS -H "Authorization: Bearer $ghe" \
  "https://llm-gateway.simulprod.com/sapi-authorization/v1/lca/ghe-exchange?aud=rbx.${env}.mcp-gateway" \
  2>/dev/null || true)"
if [ -z "$body" ]; then
  echo "get_token.sh: GHE->LCA exchange returned empty (network? llm-gateway down?)" >&2
  exit 1
fi

token="$(printf '%s' "$body" | jq -r '.token // empty' 2>/dev/null || true)"
if [ -z "$token" ]; then
  echo "get_token.sh: GHE->LCA exchange response had no .token field: $body" >&2
  exit 1
fi

printf '%s' "$token"
