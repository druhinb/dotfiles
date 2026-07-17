---
name: elasticsearch-hot-reload-credentials-migration
description: >
  Set up hot-reloading Elasticsearch managed credentials on a BEDEV2 service
  (C#, Go, or Python) so creds rotate from Vault with no service restart —
  both migrating an existing service off static credentials and standing up a
  brand-new (greenfield) service with hot-reload from the start. C# services
  adopt Roblox.RobloxElasticsearchClient 2.0.0, which is generic over the client
  type and works with ANY Elasticsearch client — ES7 (NEST/Elasticsearch.Net) or
  ES8 (Elastic.Clients.Elasticsearch) — by supplying a ~15-line client builder;
  Go services on go-elasticsearch (v7 or v8) adopt the eshotreload library
  (NewStore + eshv7/eshv8 NewClient); Python services on elasticsearch-py (v7 or
  v8) adopt the roblox-eshotreload library (new_started_store +
  eshotreload.es7/es8 new_client). Use when a service constructs its own
  Elasticsearch client (new ElasticsearchClient(...), ElasticsearchClientSettings,
  BasicAuthentication, ElasticsearchClientFactory in C#; elasticsearch.NewClient
  with Username/Password/APIKey in Go; Elasticsearch(basic_auth=..., api_key=...)
  or connection_class with static auth in Python), reads ES creds from env vars /
  appsettings / config (ElasticSearchUsername, ElasticSearchPassword,
  ElasticsearchClientSettings__*, ELASTIC_CLIENT_USER_*, ES_USERNAME/ES_PASSWORD,
  ES_API_KEY), needs to adopt managed credentials / managed_secrets.json, set
  meta.EnableManagedCredentials, stop restarting on credential rotation, or is
  asked to move to hot-reloading / rotating Elasticsearch credentials. Also use
  when a new or greenfield service needs to add an Elasticsearch client with
  rotating/hot-reload credentials, or a service already has an ES client but no
  managed-credentials wiring yet. Also covers eshotreload,
  http.RoundTripper-based credential injection (Go), the elastic_transport Node /
  elasticsearch.connection subclass injection (Python), and the ccgen
  managed_secrets.json schema. As of library 2.0.0 there is NO client-version
  gate in C#: NEST (Nest, IElasticClient) and Elasticsearch.Net
  (IElasticLowLevelClient) services adopt hot-reload directly via their own
  builder — no v7→v8 rewrite required first (a v7→v8 client migration is a
  separate, optional concern for ES9 readiness, not a prerequisite for credential
  hot-reload). Go and Python have no such gate either — v7 and v8 wrappers ship
  side by side.
---

# Elasticsearch Hot-Reload Credentials Migration

Move a service off **statically-injected Elasticsearch credentials** (env vars
baked in at process start, requiring a Nomad restart on every Vault rotation)
and onto a hot-reloading credential source backed by the framework-mounted
`/secrets/ccgen/managed_secrets.json` — **no restart, no dropped in-flight
queries**. This works for C#, Go, and Python services; the code recipe
differs by language but the concepts, cluster-name join key, and deployment
change are shared.

The code change is small and mechanical. The hard part is the **wiring**: the
cluster name must match the ccgen Vault slug, the credentials must actually be
provisioned into Vault, and the deployment file must opt into managed
credentials. Mirror the reference exactly; do **not** redesign the service's ES
layer "while you're in there".

**New / greenfield service?** This skill covers that too. The end state and the
code wiring are identical — a greenfield service is just **migration minus the
removal steps** (there's no old client, factory, or static cred env vars to take
out). Follow the same steps; wherever a step says "remove/delete the old X,"
skip it. The one thing greenfield *always* needs is the provisioning prerequisite
below (a brand-new service has no credentials in Vault yet). Step 0 has an
explicit greenfield branch.

## Why this migration exists (so you can explain it in the PR)

Org policy requires Elasticsearch credentials to rotate on a schedule. Today
most services receive creds as env vars rendered by a Vault template into
`secrets/file.env`; env vars are snapshotted at process start, so a rotation
means a **task restart** to pick up the new value. The hot-reload libraries
replace that transport with a watched source (a JSON config source in C#, an
`fsnotify` watcher behind an `http.RoundTripper` in Go), so rotations are
invisible to the running service.

**None of the three languages gate on the client version anymore:**

- **C#** adopts `Roblox.RobloxElasticsearchClient` **2.0.0**, which is **generic
  over the client type** and carries no Elasticsearch dependency of its own. You
  supply a ~15-line `ElasticsearchClientBuilder<TClient>` that constructs your
  concrete client; the library does the bind / diff / atomic-swap / dispose. So
  **ES7 (NEST / `Elasticsearch.Net`) and ES8 (`Elastic.Clients.Elasticsearch`)
  are both eligible with no rewrite.** (1.x was ES8-only and pinned to
  `8.13`–`8.15`; 2.0.0 removes that ceiling.)
- **Go** injects credentials at the HTTP layer via `eshotreload`, which ships
  wrappers for **both `go-elasticsearch` v7 and v8**. A v7 Go service can adopt
  hot-reload without a rewrite.
- **Python** injects credentials at the transport layer via `roblox-eshotreload`,
  which ships wrappers for **both `elasticsearch-py` 7.x and 8.x** (via the
  `[es7]` / `[es8]` extras). A v7 Python service can adopt hot-reload without a
  rewrite.

> A v7→v8 **client** migration (NEST → `Elastic.Clients.Elasticsearch`) is still
> worth doing eventually for ES9 readiness, but it is a **separate, independent**
> effort owned by the storage team — **not** a prerequisite for credential
> hot-reload. Do not block this migration on it.

## Agent Commit Hygiene

This skill is a migration aid. Anything you **commit** to the target repo must
stand on its own without referencing this skill. Specifically, in code, config,
or commit/PR text that lands in the repo:

- Do **not** cite this skill by name, and do **not** reference its step labels
  ("Step 0", section names like "Per-env URL transport") in committed text.
- Comments must explain the underlying fact (what the library expects, why a
  value is required), not point at a doc that won't exist in the repo later.

You may use these labels freely in chat — they're an authoring convenience here.

## Git Safety Rules

- **NEVER force push.** If updating an already-pushed branch,
  `git pull --rebase` first, then commit and push normally.
- **One PR per service** in the code repo; **one PR per service** in the
  deployment repo. Keep them linked in the descriptions.
- Title the code PR with the change + service name, e.g.
  `adopt RobloxElasticsearchClient for hot-reloading credentials in <service>`.

---

## Step 0: Detect the language, then confirm eligibility

First figure out whether the service is C#, Go, or Python, then apply the
matching eligibility rule. The rest of the steps differ only in the code
recipe.

```bash
# C#: a .csproj with an Elasticsearch package reference
git grep -nE "Elastic\.Clients\.Elasticsearch|Include=\"NEST\"|Include=\"Nest\"|Elasticsearch\.Net" -- '*.csproj' '*.cs'
# Go: a go.mod / imports referencing go-elasticsearch
git grep -nE "github.com/elastic/go-elasticsearch/v[78]|olivere/elastic" -- 'go.mod' '*.go'
# Python: a pyproject.toml / requirements.txt / imports referencing elasticsearch-py
git grep -nE "^elasticsearch(\[|=|>|<|\s|$)|\"elasticsearch(\[|=|>|<)|from elasticsearch\b|import elasticsearch\b" -- 'pyproject.toml' 'requirements*.txt' 'setup.py' 'setup.cfg' '*.py'
```

### If nothing matches — greenfield / new service

If **none of the greps find an Elasticsearch client** (a brand-new service, or a
service adding ES for the first time), this is the **greenfield** path. There's
nothing to gate and nothing to remove — you're adding hot-reload-ready ES from
the start:

- Pick the language from what the repo *is*: a `.csproj` → C#; a `go.mod` → Go;
  a `pyproject.toml` / `requirements.txt` → Python.
- **C#:** add `Roblox.RobloxElasticsearchClient` **`2.0.*`** plus your chosen
  Elasticsearch client at whatever version you like — **there is no version pin to
  manage** (2.0.0 carries no `Elastic.Transport` dependency, so the old `8.15.x`
  ceiling is gone). New services should generally start on the **v8 client**
  (`Elastic.Clients.Elasticsearch`) for ES9 readiness, but ES7/NEST works too. You
  write a ~15-line builder for that client — see `references/csharp-library-recipe.md`
  §1.5.
- **Go:** start on **`go-elasticsearch/v8`** + the **`eshotreload/v8`** wrapper.
- **Python:** start on **`elasticsearch-py 8.x`** + **`roblox-eshotreload[es8]`**.
- Skip every "remove the old X / delete the dead factory" instruction in the
  later steps — there's nothing there yet.
- **Do not skip the provisioning prerequisite** — a new service has no creds in
  Vault, so the Secrets Broker onboarding below is required, not optional.

Then go to the **Prerequisites** section, then **Step 1**, using the C# or Go
recipe as your starting point (take the "after" code; ignore the migration diffs'
"before"/removal lines).

> The remaining detail in this Step 0 is for **migrating** services (those where
> a grep above *did* match). Greenfield services can skip straight past it.

### If C# — both ES7 and ES8 are eligible (no rewrite)

As of library **2.0.0** the engine is generic over the client type, so the client
version no longer gates adoption — you just supply the matching ~15-line builder.

| What you find | Action |
| --- | --- |
| `Elastic.Clients.Elasticsearch` (v8) | Eligible — supply the **ES8 builder** (`Es8ClientBuilder`); model: `services/elasticsearch-hot-reload-example` |
| `NEST` / `using Nest;` / `IElasticClient` (v7) | Eligible — supply the **ES7 NEST builder** (`Es7NestClientBuilder`); model: `services/es-creds-package-hot-reload-example`. **No v7→v8 rewrite needed.** |
| `Elasticsearch.Net` / `IElasticLowLevelClient` (v7) | Eligible — supply a builder returning `ElasticLowLevelClient`, built from `ConnectionConfiguration` (not NEST's `ConnectionSettings`). No NEST dependency needed. See `references/csharp-library-recipe.md` §1.5 (low-level variant) |
| Mixed (v8 **and** NEST/Es.Net) | Eligible — register one provider per client type (`AddRobloxElasticsearchClients<ElasticsearchClient>(...)` **and** `<ElasticClient>(...)`), each with its own builder |

> A v7→v8 **client** migration is still worthwhile for ES9 readiness and is owned
> by the storage team (`@roblox/storage-stateful-infra-management`), but it is a
> **separate** effort — do **not** block credential hot-reload on it. ES7/NEST
> services hot-reload today via their own builder.

Then go to **Step 1**, and use `references/csharp-library-recipe.md` for the
code change (it shows both the ES8 and ES7 builders side by side).

### If Go — both v7 and v8 are eligible (no rewrite)

`eshotreload` injects credentials beneath the client via an `http.RoundTripper`,
so the client's major version doesn't gate adoption.

| What you find | Action |
| --- | --- |
| `go-elasticsearch/v8` | Eligible — use the `eshotreload/v8` wrapper |
| `go-elasticsearch/v7` | Eligible — use the `eshotreload/v7` wrapper (no rewrite needed) |
| `olivere/elastic` (third-party) | Not covered by the wrapper; use the core `eshotreload.Store` + `eshotreload.Transport` directly, or consult the storage team |

Then go to **Step 1**, and use `references/go-eshotreload-recipe.md` for the
code change. (Steps 3's URL-transport gotcha is C#-only — see the note there.)

### If Python — both v7 and v8 are eligible (no rewrite)

`roblox-eshotreload` injects credentials via a per-request transport seam (an
`elastic_transport.Node` subclass for v8; an
`elasticsearch.connection.Urllib3HttpConnection` subclass for v7), so the
client's major version doesn't gate adoption.

| What you find | Action |
| --- | --- |
| `elasticsearch>=8` / `elasticsearch-py 8.x` (`Elasticsearch()`, `basic_auth=`, `api_key=`) | Eligible — install `roblox-eshotreload[es8]` and use `eshotreload.es8.new_client` |
| `elasticsearch>=7,<8` / `elasticsearch-py 7.x` (`Elasticsearch()`, `http_auth=`, `api_key=`) | Eligible — install `roblox-eshotreload[es7]` and use `eshotreload.es7.new_client` (no rewrite needed) |
| Third-party clients (e.g. `elasticsearch-async`, `aioelasticsearch`) | Not covered by the wrappers; use the core `Store` + `apply_auth` transport helpers directly, or consult the storage team |

> Never install both extras into the same interpreter — `[es7]` and `[es8]`
> pin conflicting `elasticsearch` versions. Pick one, matching whatever your
> service already uses.

Then go to **Step 1**, and use `references/python-eshotreload-recipe.md` for
the code change. (Step 3's URL-transport gotcha is C#-only — see the note
there; Python builds the address itself, same as Go.)

## Prerequisites: confirm credentials are provisioned into Vault

The code change is inert until rotated ES credentials are actually being minted
into the service's Vault path and rendered into `managed_secrets.json` — if the
file has no entry for the cluster, the client comes up with no credentials even
though the wiring is correct.

For a **migrating** service this is almost always already in place (it's where
the current static creds come from) — just confirm the Vault path exists and move
on. Only act here if it's missing or you're standing up a **new cluster**: the
storage team provisions the cluster and an onboarding config must be landed in
the Secrets Broker so creds are minted (auto-rotated every 7 days, 37-day TTL).
See `references/provisioning-managed-credentials.md` for the onboarding template
and steps. If unsure whether a cluster/path exists, ask the storage team
(`@roblox/storage-stateful-infra-management`) before writing code against it.

## Step 1: Identify the cluster name (the join key)

All three libraries key everything off a **cluster name** that must be
identical in these places:

1. The key under `providers[name="elasticsearch"].config.<name>` in
   `/secrets/ccgen/managed_secrets.json` — credentials.
2. The `cluster_name` in the Secrets Broker onboarding config, which produces the
   Vault path `secretv2/data/products/<product>/<service>/elasticsearch_data/<name>`
   (see `references/provisioning-managed-credentials.md`).
3. The name you pass in code: `ForCluster("<name>")` (C#) /
   `NewClient(store, "<name>", …)` (Go) /
   `new_client(store, cluster="<name>", …)` (Python), plus the static URL config
   keyed by the same name (`ElasticsearchClusters:<name>` in C# appsettings; the
   address you build for that cluster in Go / Python code).

This name is always hyphenated and prefixed with `es-`, e.g.
`es-cs-cases-search`, `es-transactionrecords`. **Do not invent it.**
For a **migrating** service, find the authoritative value in the deployment
repo's Vault template (the existing `secretv2/.../elasticsearch_data/<slug>` path
the current credential env vars are rendered from). For a **new** service, it's
the `cluster_name` you put in the Secrets Broker onboarding config. When in
doubt, ask the storage team to confirm the slug.

Getting this wrong is the #1 cause of a missing client at runtime —
`ForCluster` returning `null` (C#), `ErrCredentialsNotFound` on the next
request (Go), or `CredentialsNotFoundError` bubbling out of the transport
(Python).

## Step 2: Make the code change

Apply the recipe for your language:

- **C#** — `references/csharp-library-recipe.md`. Adds
  `Roblox.RobloxElasticsearchClient` `2.0.*`, writes a ~15-line
  `ElasticsearchClientBuilder<TClient>` for your client (ES8 or ES7 — the only
  version-specific code), replaces the hand-rolled client/factory with
  `services.AddRobloxElasticsearchClients<TClient>(Configuration, BuildClient)`,
  injects `IElasticsearchClientProvider<TClient>` and resolves `ForCluster(name)`
  **per call**, reshapes settings to `ElasticsearchClusters`, deletes the dead
  factory, updates tests. (Two wiring shapes: Path A binds from `IConfiguration`;
  Path B passes static config from an existing `Settings.cs`. Default is Path A.)
- **Go** — `references/go-eshotreload-recipe.md`. Adds the `eshotreload` core +
  the `eshv7`/`eshv8` wrapper matching your `go-elasticsearch` major version,
  starts the `Store` once at startup, builds the client with
  `NewClient(store, cluster, cfg)` (credentials stripped from `cfg`), and removes
  the old username/password plumbing.
- **Python** — `references/python-eshotreload-recipe.md`. Installs
  `roblox-eshotreload` with the `[es7]` or `[es8]` extra matching your
  `elasticsearch-py` major version, starts the `Store` once at startup via
  `new_started_store()`, builds the client with
  `new_client(store, cluster=..., hosts=[...])` (static auth kwargs rejected),
  and removes the old username/password plumbing.

> **Greenfield:** the recipes are written as migration diffs. Take only the
> "after" code (the additive `+` lines) — there's no existing client, factory, or
> static cred plumbing to replace or remove. The "delete the dead factory" and
> "remove old credentials" steps simply don't apply.

## Step 3: Per-env URL transport

**This step is C#-only.** The C# library reads cluster URLs from .NET
`IConfiguration`. The config key contains the (hyphenated) cluster name, e.g.
`ElasticsearchClusters__es-user-communications__Urls__0`.

**Define this env var correctly in the deployment file — do not add a code-side
workaround.** Earlier guidance suggested a `Program.cs` env-var bridge
(`ConfigureAppConfiguration` + `AddInMemoryCollection`) to translate an
env-var-safe name into the hyphenated config key. That is **no longer
recommended** — it adds code for nothing. The hyphen restriction only applies to
the consul-template `template { env = true }` secrets block; the **literal Nomad
`env { }` block accepts hyphens**, so just write the real config key there:

```hcl
env {
  ElasticsearchClusters__es-user-communications__Urls__0 = "https://es-user-communications-<per-env-host>"
}
```

.NET binds `__` → `:` natively, so the URL lands in `ElasticsearchClusters` with
no `Program.cs` change. See `references/deployment-recipe.md` for the per-env
hostnames and details.

> Set **only the URL**. The library defaults the request timeout to 30s, so
> there's no `RequestTimeoutSeconds` to set — leave it out unless you're
> deliberately preserving a non-default timeout the old client used (see the C#
> recipe). This migration's scope is credentials + the URL the client can't work
> without.

> Only if the URL must genuinely rotate **live** (follow a Vault change without a
> redeploy) reach for the JSON-template pattern (`AddJsonFile(reloadOnChange:
> true)`) in the deployment recipe. Static per-env DNS names — the normal case —
> just go straight in the `env { }` block above.

**Go and Python services skip this entirely** — both build the cluster
address in code (from a plain env var like `ES_ADDRESS` / `ES_DATACENTER`, no
`IConfiguration` and no hyphen problem). See the Go and Python recipes.

## Step 4: Make the deployment change

In the deployment repo, edit **only the Nomad source spec** for the service (the
`nomad/` source path) — **never** the generated output directories (e.g. a `gen/`
tree), which GitHub CI regenerates from the source on merge. Per
`references/deployment-recipe.md`:

1. Add `EnableManagedCredentials: "true"` to the `meta` block. *(Same for C#,
   Go, and Python — this is what makes ccgen render the `elasticsearch`
   provider into `managed_secrets.json`.)*
2. Remove the now-obsolete ES credential env vars (e.g.
   `ElasticsearchClientSettings__Username/Password`, `ELASTIC_CLIENT_USER_*`,
   `ES_USERNAME`/`ES_PASSWORD`, `ES_API_KEY`) from the `secrets/file.env`
   template — they're replaced by `managed_secrets.json`. *(Greenfield: nothing
   to remove — skip.)*
3. Supply the per-env URL: **C#** via the Step 3 pattern you chose; **Go and
   Python** via the plain env var the service already reads (e.g. `ES_ADDRESS`,
   or `ES_DATACENTER` + `ES_CLUSTER_NAME`) — no special pattern needed.
4. Apply to the sitetests (`sitetest1`, `sitetest2`, `sitetest3`) and
   `production`. **Skip Luobu** (`luobu*`) — out of scope; make no changes there.

> Credentials only start flowing through `managed_secrets.json` once
> `EnableManagedCredentials: "true"` is deployed. Until then the client has no
> credentials — `ForCluster` returns `null` (C#) / requests fail with
> `ErrCredentialsNotFound` (Go) / requests fail with `CredentialsNotFoundError`
> (Python). The code PR is safe to merge first **only if** the old env-var
> creds remain in place until the deployment PR lands; otherwise sequence
> deployment first. Confirm the Vault path already emits ES creds for this
> product before relying on it.

## Verification

**C#**
```bash
# No hand-rolled client construction should remain.
git grep -nE "new ElasticsearchClient\(|ElasticsearchClientSettings\(|BasicAuthentication\(" -- '*.cs'
# Expect: no hits outside tests / the library itself.
# Before deleting the old factory/settings file, confirm nothing else uses it —
# it may be shared by another project (cross-project <Compile Include>, Dockerfile
# COPY) or define a non-credential type some other code reads.
git grep -nE "ElasticsearchClientFactory|ElasticsearchClientSettings" -- '*.csproj' '*.cs'
grep -rn "ElasticsearchClientFactory" --include=Dockerfile* .
dotnet build    # build the WHOLE solution, not just this service — a shared file
                # deletion breaks the dependent project here, not in your service
dotnet test     # unit tests pass (client provider is now faked, not the raw client)
```
If the factory file is shared, handle the dependent project in the **same PR**
(move the non-credential parts out, or migrate that consumer too) — see recipe
§6. A blind delete that breaks another project's build/Docker image is the most
common avoidable failure.
After deploy, the C# library logs a rebuild line on every reload:
```
ES clients rebuilt: reason="startup"  active=1 added=1 ...
ES clients rebuilt: reason="credentials-changed" active=1 rebuilt=1 retired=1 ...
```
`reason="startup"` proves config bound; `reason="credentials-changed"` after a
rotation proves hot-reload works.

**Go**
```bash
# No static credentials should remain on the elasticsearch.Config.
git grep -nE "Username:|Password:|APIKey:" -- '*.go'   # expect none feeding elasticsearch.Config
go build ./...   # succeeds
go test ./...    # passes
```
After deploy, confirm the store loaded the file (the example logs via the
injected `slog.Logger`) and issue a request after a rotation; it should succeed
without a restart. A `nil` store logger means no log output — pass one to see
reload events.

**Python**
```bash
# No static credentials should remain on the Elasticsearch(...) call site.
git grep -nE "basic_auth=|api_key=|http_auth=|bearer_auth=" -- '*.py'   # expect none feeding Elasticsearch(...)
python -m pytest   # passes
```
After deploy, watch the service's logs for the `eshotreload.store` logger.
The library logs the initial load and every successful reload at `INFO`,
including the resolved username per cluster — the format is
`loaded managed secrets: elasticsearch[<cluster>=<username>]` at startup and
`reloaded managed secrets: elasticsearch[<cluster>=<new-username>]` after a
rotation. The `<username>` value flipping to the new timestamped identity is
the unambiguous signal that the running client picked up the rotated
credential. If the callback registered via `store.on_reload(...)` doesn't
fire, the file wasn't actually rewritten (or the watcher wasn't started —
verify the store came from `new_started_store()` at process boot, not
constructed by hand without `.start()`).

### Run the service's component / integration tests — and fix readiness races `[all]`

A credential migration adds a package, a DI registration, and (often) a new
constructor on the ES wiring. That alone rarely breaks the dockerized
**component / integration test** suite — but those suites are frequently
**already flaky** in customer repos for an unrelated reason, and a
credential-migration PR is exactly when CI surfaces it. **Run them locally and
get them green before you push** — do not wave a red component job through as
"pre-existing, not mine."

Most customer component suites spin the service up against real dependencies
(Elasticsearch, a fixture/index seeder, mocks) via `docker-compose`. Crucially,
`docker-compose` `depends_on` **waits only for container _start_, not
readiness** — so two races are common:

- The index/fixture seeder fires requests at Elasticsearch before ES accepts
  connections (ES 7.x needs ~20–40s), fails silently, and **creates no index**.
- The test host runs immediately and queries **before the fixtures are indexed**.

**Symptom (very recognizable):** the health-check test passes, but **every
ES-backed test fails with HTTP 500 / "Server Error" and an empty body** (the
service throws `index_not_found_exception` or connection-refused underneath).
It is timing-dependent, so it fails "on almost every PR" yet occasionally passes.

**This is a harness bug, not your code** — the credential change is inert until
`managed_secrets.json` exists, so it cannot cause this. Fix the harness in the
**same PR** so CI is green:

1. **Make the seeder wait for ES and fail loudly.** Poll
   `/_cluster/health?wait_for_status=yellow` until ready (bounded, e.g. ~120s)
   before creating the index; bulk-load with `?refresh=wait_for` so docs are
   immediately searchable; run the script under `set -eu` (POSIX `sh` if it runs
   on alpine/busybox) so a real failure is a non-zero exit instead of silent.
2. **Gate the tests on data readiness.** In test setup (e.g. NUnit
   `[OneTimeSetUp]` for C#, `TestMain` / a `TestcontainersSuite` fixture for
   Go, `pytest` session-scoped fixture for Python), poll the real query path
   until the seeded document comes back (bounded, e.g. ~180s) before any test
   runs — proving the test → service → Elasticsearch chain is actually up.
   Never rely on `depends_on` alone.

Confirm locally with a genuine cold start (bring ES up and the seeder at the same
instant): the seeder should wait, then create and populate a searchable index,
and the suite should pass **deterministically across repeated runs**.

If credentials never take effect, the cluster name or `EnableManagedCredentials`
is wrong. See `references/gotchas.md` for the full failure table (tagged
`[C#]` / `[Go]` / `[Py]`).

## PR Deliverables

**Code PR (C#)**
- `.csproj`: `Roblox.RobloxElasticsearchClient` `2.0.*` added; framework
  `>= 13.117.2`; your own Elasticsearch client `<PackageReference>` (NEST 7.x or
  `Elastic.Clients.Elasticsearch` 8.x) — **no version pin to manage** (2.0.0 has
  no transport ABI ceiling).
- A ~15-line `ElasticsearchClientBuilder<TClient>` (e.g. `Es8ClientBuilder` /
  `Es7NestClientBuilder`) in a small static class — the only version-specific code.
- Client construction replaced by `IElasticsearchClientProvider<TClient>` resolved
  per call.
- Dead factory class + its tests removed; remaining tests fake the provider.
- Description: what cluster, which client (ES7/ES8), which wiring path (A/B), and a
  note that creds now come from `managed_secrets.json` (the URL is set in the
  deployment `env {}` block; no `Program.cs` URL bridge).

**Code PR (Go)**
- `go.mod`: `eshotreload` core + the `eshv7`/`eshv8` wrapper matching the client.
- `Store` started once at startup; client built via `NewClient(store, cluster, cfg)`
  with credentials removed from `cfg`.
- Old username/password env plumbing removed.
- Description: what cluster, which wrapper (v7/v8), and that creds now come from
  `managed_secrets.json`.

**Code PR (Python)**
- `pyproject.toml` / `requirements.txt`: `roblox-eshotreload` added with the
  `[es7]` or `[es8]` extra matching your existing `elasticsearch-py` major
  version (never install both extras into the same interpreter).
- `Store` started once at startup via `new_started_store()` (or
  `shared_started_store()` for processes that build multiple credentialed
  clients); client built via `new_client(store, cluster=..., hosts=[...])`
  with all static auth kwargs (`basic_auth`/`api_key`/`http_auth`/`bearer_auth`)
  removed from the call site.
- Old username/password/API-key env plumbing removed from the service's config
  module.
- Description: what cluster, which extra (`es7`/`es8`), and that creds now come
  from `managed_secrets.json`.

**Deployment PR**
- `meta.EnableManagedCredentials: "true"` on every env.
- Old ES credential env vars removed from `secrets/file.env`.
- Per-env URL added per chosen pattern.
- Description: link to the code PR; note the rotation behavior change.

---

## Reference files

Read these as you reach each step — don't load them all up front.

- `references/csharp-library-recipe.md` — **C#** code-side migration with
  concrete diffs (csproj, the ES8 + ES7 client builders, Startup, call site,
  Settings/appsettings, tests, Path A vs B).
- `references/go-eshotreload-recipe.md` — **Go** code-side migration
  (`eshotreload` store + `eshv7`/`eshv8` wrapper, startup wiring, removing static
  creds).
- `references/python-eshotreload-recipe.md` — **Python** code-side migration
  (`roblox-eshotreload` store + `eshotreload.es7`/`eshotreload.es8` wrapper,
  startup wiring, removing static creds).
- `references/provisioning-managed-credentials.md` — Secrets Broker onboarding
  (the prerequisite that mints rotated creds into Vault). Needed mainly for new
  services / first-time clusters.
- `references/deployment-recipe.md` — the Nomad/`cc.yml` change (shared) and the
  three per-env URL transport patterns (C#-only) in full.
- `references/gotchas.md` — the failure-symptom table, tagged `[C#]` / `[Go]` /
  `[Py]`, plus verification detail.

### Model references (ground truth — prefer mirroring these over improvising)

- **C# ES8 — in-repo example (library 2.0.0, `ProjectReference`)** —
  [`storage-resources-demo`](https://github.rbx.com/Roblox/storage-resources-demo)
  → `services/elasticsearch-hot-reload-example` (cluster `es-tags`; builder at
  `src/Elasticsearch/Es8ClientBuilder.cs`). The canonical
  `Elastic.Clients.Elasticsearch` adoption.
- **C# ES7 / NEST — in-repo example (library 2.0.0)** —
  `services/es-creds-package-hot-reload-example` (cluster `es-tags`; builder at
  `src/Elasticsearch/Es7NestClientBuilder.cs`). The line-for-line NEST counterpart
  of the ES8 example — mirror this for any NEST / `Elasticsearch.Net` service.
- **C# (merged, in production — 1.x era)** —
  [safety-platform-processors#1699](https://github.rbx.com/Roblox/safety-platform-processors/pull/1699)
  (`cs-cases-indexer`, cluster `es-cs-cases-search`). Still a good model for the
  deployment + wiring shape, but it predates 2.0.0 — it has no builder and pins
  `8.15.x`; for the code surface prefer the two in-repo examples above.
- **Go (in-repo demo, not yet a production customer)** —
  [`storage-resources-demo-go`](https://github.rbx.com/Roblox/storage-resources-demo-go)
  → `services/storage-resources-demo-go/internal/clients/clients.go`. Treat as a
  worked example, not battle-tested at customer scale yet; validate carefully.
- **Python (in-repo demo, not yet a production customer)** —
  [`storage-resources-demo`](https://github.rbx.com/Roblox/storage-resources-demo)
  → `pkg-python/eshotreload/examples/query_loop.py` (hot-reload query loop; runs
  against any cluster from `managed_secrets.json`, prints reload log lines as
  credentials rotate). Treat as a worked example, not battle-tested at customer
  scale yet; validate carefully.

### Library source of truth (if this skill disagrees, the library wins)

- C#: [`libs/RobloxElasticsearchClient/README.md`](https://github.rbx.com/Roblox/storage-resources-demo/blob/master/libs/RobloxElasticsearchClient/README.md)
  (2.0.0 — generic builder, ES7 + ES8 snippets, Path A/B) and
  [`IElasticsearchClientProvider.cs`](https://github.rbx.com/Roblox/storage-resources-demo/blob/master/libs/RobloxElasticsearchClient/IElasticsearchClientProvider.cs);
  in-repo services `services/elasticsearch-hot-reload-example` (ES8) and
  `services/es-creds-package-hot-reload-example` (ES7/NEST).
- Go: [`pkg/eshotreload/README.md`](https://github.rbx.com/Roblox/storage-resources-demo-go/blob/main/pkg/eshotreload/README.md)
  plus the `pkg/eshotreload/v7` and `pkg/eshotreload/v8` wrapper READMEs.
- Python: [`pkg-python/eshotreload/README.md`](https://github.rbx.com/Roblox/storage-resources-demo/blob/master/pkg-python/eshotreload/README.md)
  plus the `pkg-python/eshotreload/src/eshotreload/es7/` and
  `pkg-python/eshotreload/src/eshotreload/es8/` wrapper modules.
