# Provisioning Managed Credentials (Secrets Broker)

Before any of the code wiring works, rotated Elasticsearch credentials must be
minted into the service's Vault path so ccgen can render them into
`managed_secrets.json`. This is handled by the **Secrets Broker** /
Elasticsearch Secret Consumer onboarding, owned by the storage team.

This step has lead time and **gates the end-to-end test** — start it first (or in
parallel with the code change), not after.

Canonical runbook (authoritative; if this file disagrees, the runbook wins):
[Secrets Broker Service](https://roblox.atlassian.net/wiki/spaces/INFOSEC/pages/2644443301/Secrets+Broker+Service).

## Who does what

- **Storage team** creates the Elasticsearch cluster (for new clusters) and owns
  the Secret Provider that mints/revokes the concrete credentials.
- **You / the service team** land an onboarding config that tells the broker to
  provision credentials for your service+cluster into your Vault path.
- The **Secrets Broker** handles the handover, scheduled rotation (every 7 days),
  and revoke. Credentials carry a 37-day TTL to satisfy Infosec.

If you're not sure whether a cluster or Vault path already exists (common for
migrating services — it usually does), ask
`@roblox/storage-stateful-infra-management` before writing the config.

## How to onboard

Open a PR adding a file to
[`Roblox/secrets-broker-configs`](https://github.rbx.com/Roblox/secrets-broker-configs)
under `onboarding-configs/storage-stateful-control-plane/elasticsearch_data-<service>.yaml`.
Copy a recent neighbor in that directory rather than this template verbatim — the
live examples track the current schema.

```yaml
---
service_name: <bedev2-service>

secret_provider:
  name: storage-stateful-control-plane
  # Base path under the secretv2 mount. The suffix
  # "elasticsearch_data/<cluster_name>" is appended automatically, so the full
  # path becomes:
  #   secretv2/data/products/<product>/<bedev2-service>/elasticsearch_data/<cluster_name>
  vault_path: secretv2/data/products/<product>/<bedev2-service>
  technology: elasticsearch_data
  cluster_name: es-<cluster>          # MUST be prefixed with "es-"
  team: <team>
  # username_prefix should match your bedev2 service — important when multiple
  # services point at the same cluster (keeps their identities distinct).
  username_prefix: <bedev2-service>

  # Optional fields (omit to take defaults):
  # needs_api_key: false              # true if you need an API key, not user/pass
  # read_only: false                  # true for read-only credentials
  # allowed_indices: index1,index2    # default: all indices on the cluster
  # allow_restricted_indices: false
  # datacenters: sitetest3,chi1,ash1  # default/"all": every datacenter
```

> **One service per `vault_path` + cluster.** Don't point two services at the same
> Vault path/cluster entry — give each its own onboarding config and
> `username_prefix`.

After the PR merges, the broker mints credentials at
`secretv2/data/products/<product>/<service>/elasticsearch_data/<cluster>`. With
`meta.EnableManagedCredentials: "true"` set (Step 4), ccgen renders them into
`/secrets/ccgen/managed_secrets.json` under
`providers[name="elasticsearch"].config.<cluster_name>` — which is exactly the
join key the code reads (Step 1).

## Auth shape that lands in `managed_secrets.json`

The minted fields become per-cluster entries the libraries consume:

```json
{ "providers": [ { "name": "elasticsearch", "config": {
  "es-<cluster>": { "username": "u", "password": "p" }   // or { "api_key": "..." } if needs_api_key
} } ] }
```

Both libraries prefer `api_key` over basic auth when both are present.

## Verifying the secret exists (debugging)

Authenticate with your service, then:

```bash
vault kv list -mount=secretv2 products/<product>
# then drill into the elasticsearch_data/<cluster> path to confirm fields are present
```

If `ForCluster` returns `null` (C#) or requests fail with `ErrCredentialsNotFound`
(Go) after deploy, the usual cause is this provisioning isn't in place yet, the
config hasn't merged/activated, or the `cluster_name` here doesn't match the name
used in code and `managed_secrets.json`. See `gotchas.md`.
