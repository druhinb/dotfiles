# Deployment Recipe (Nomad / `cc.yml` side)

The deployment-repo change that turns on managed credentials and supplies the
per-env cluster URL. Apply after the code PR is ready. These edits live in the
deployment repo's `unified-spec` (Nomad `cc.yml`) for the service, per
environment.

> **Only edit the Nomad source directory.** Make all changes in the hand-authored
> Nomad spec for the service (the `nomad/` source path). Do **not** edit generated
> directories (e.g. a `gen/` tree or any other rendered output) — those are
> produced automatically by GitHub CI from the source spec on merge, and
> hand-editing them will be overwritten and just creates noise/conflicts. If you
> see the same `cc.yml`-style content mirrored under a generated path, leave it
> alone and change only the source.

## Table of contents

1. Turn on managed credentials (`meta`)
2. Remove the old credential env vars
3. Supply the per-env URL (define it correctly in the `env {}` block)
4. Per-environment checklist

---

## 1. Turn on managed credentials

Add `EnableManagedCredentials: "true"` to the service's `meta` block. This is
what makes ccgen render the `elasticsearch` provider block into
`/secrets/ccgen/managed_secrets.json`, which the framework auto-mounts and the
library reads.

```diff
 meta:
   BEDEV2ServiceType: kafka-processor
   EnableBloxIDAgentSocket: "true"
+  EnableManagedCredentials: "true"
   EnableSquidProxy: "true"
```

This single flag is the only deployment-side decision for credentials. It
requires the product's Vault path to already emit ES creds at
`secretv2/data/products/<product>/elasticsearch_data/<cluster>` — for most
audited products that's already true. Confirm with the storage team if unsure.

## 2. Remove the old credential env vars

The hand-rendered username/password lines in the `secrets/file.env` template are
now obsolete — credentials arrive via `managed_secrets.json`. Delete them and
leave a short comment so the next reader knows where creds went.

```diff
       - destination: secrets/file.env
         env: true
         data: |
           # Kafka settings
           KafkaSaslUsername={{with secret "..."}}{{index .Data.data "username"}}{{end}}
           KafkaSaslPassword={{with secret "..."}}{{index .Data.data "password"}}{{end}}

-          # Elasticsearch settings (whatever your service named them, e.g.
-          # <EsSettings>__Username / ELASTIC_CLIENT_USER_USERNAME, etc.)
-          <EsSettings>__Username={{ with secret "secretv2/data/products/<product>/elasticsearch_data/<cluster>" }}{{ .Data.data.es_client_user_username }}{{ end }}
-          <EsSettings>__Password={{ with secret "secretv2/data/products/<product>/elasticsearch_data/<cluster>" }}{{ .Data.data.es_client_user_password }}{{ end }}
+          # Elasticsearch credentials now come from /secrets/ccgen/managed_secrets.json
+          # (meta.EnableManagedCredentials) and hot-reload on Vault rotation.
```

Leave **non-credential** ES settings (like the URL) alone here — those are
handled in the next section.

## 3. Supply the per-env URL (define it correctly in the `env {}` block)

> **C# only.** Go and Python services build the cluster address in code from a
> plain env var (e.g. `ES_ADDRESS`, or `ES_DATACENTER` + `ES_CLUSTER_NAME`) —
> there's no `IConfiguration` binding and no hyphen problem. Just set that env
> var per environment in the deployment file like any other. Steps 1 and 2
> (the `meta` flag and removing old credential env vars) are the same for Go
> and Python.

The C# library binds cluster URLs from `IConfiguration` under
`ElasticsearchClusters:<cluster>:Urls:0`. **Define this env var correctly in the
deployment file — do not add a code-side workaround.**

### Default: write the real config key in the `env { }` block

Put the URL and timeout directly in the literal Nomad `env { }` block, using the
full `__`-separated config key including the hyphenated cluster name. **Hyphens
are fine here** because the `env { }` block is parsed by Nomad directly, not by
consul-template. .NET binds `__` → `:`, so the value lands in
`ElasticsearchClusters:<cluster>:Urls:0` with **no `Program.cs` change**.

```hcl
env {
  ElasticsearchClusters__es-cs-cases-search__Urls__0 = "https://es-cs-cases-search-sitetest3.simulpong.com"
}
```

In `unified-spec` YAML the equivalent is the plain `env-stanza` config map. This
is the normal case — per-env URLs are well-known DNS names you write literally,
one value per environment (sitetest1/2/3, production). Where a cluster isn't
wired for an env, leave the URL empty (`""`) so the client stays dormant.

> **Set only the URL.** The library already defaults the request timeout to 30s,
> so don't add `ElasticsearchClusters__<cluster>__RequestTimeoutSeconds` — it's a
> no-op at `30` and out of scope for a credentials migration. Only set it (here or
> in `appsettings.json`) if the service's old client used a non-default timeout
> you need to preserve.

### Do NOT use a `Program.cs` env-var bridge

A previous version of this recipe suggested rendering the URL to a hyphen-free
env var (e.g. `ES_URL_CS_CASES_SEARCH`) and translating it to the hyphenated
config key with `ConfigureAppConfiguration` + `AddInMemoryCollection`. **Don't do
this.** It only existed to dodge the hyphen restriction in `template { env =
true }` blocks — but the literal `env { }` block above accepts hyphens, so the
bridge is pure dead code. Define the key correctly in the deployment file
instead; no application code change is needed for the URL.

The hyphen restriction (`key characters must be [A-Za-z0-9_.] but found '-'`)
applies **only** to consul-template `template { env = true }` secret files — not
to the literal `env { }` block. So don't put the URL in a `template { env =
true }` block.

### Rare: live URL rotation (JSON template)

Only if the URL itself must rotate **live** (follow a Vault change without a
redeploy — e.g. regional failover) do you need code. Render Vault data into a
JSON file with `change_mode = "noop"` so Nomad doesn't restart the task, and add
it as a hot-reloading config source.

```hcl
template {
  destination = "secrets/cluster-urls.json"
  change_mode = "noop"   # let the in-process FileSystemWatcher pick up the rewrite; Nomad's default "restart" would defeat the purpose
  data        = <<EOF
{ "ElasticsearchClusters": { "es-cs-cases-search": { "Urls": [ "{{ with secret "secretv2/data/products/<product>/elasticsearch_urls/<cluster>" }}{{ .Data.data.url }}{{ end }}" ] } } }
EOF
}
```

```csharp
.ConfigureAppConfiguration((_, cfg) =>
    cfg.AddJsonFile("/secrets/cluster-urls.json", optional: true, reloadOnChange: true));
```

This rides the same `JsonConfigurationProvider` + `FileSystemWatcher` chain that
hot-reloads credentials, so a URL change rebuilds just that one cluster's client.
Almost no service needs this — prefer the literal `env { }` block above.

## 4. Per-environment checklist

Apply the change to the standard environments in the service's Nomad source spec:

- All sitetests (`sitetest1`, `sitetest2`, `sitetest3`) and `production`.
- **Skip Luobu** (`luobutest`, `luobustage`, `luobuprod`) — out of scope; make no
  changes there.

For each env confirm: `meta.EnableManagedCredentials: "true"` present, old ES
credential env vars gone, and the `ElasticsearchClusters__<cluster>__Urls__0` env
var set in the `env { }` block with the correct per-env hostname. (Reminder from
the top of this doc: edit only the Nomad source directory — never the generated
output, which CI regenerates.)
