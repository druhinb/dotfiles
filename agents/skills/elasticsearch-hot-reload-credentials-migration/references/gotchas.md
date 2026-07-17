# Gotchas & Verification

The failures you'll actually hit, and how to confirm the migration worked.
These are distilled from a real merged C# adoption
([safety-platform-processors#1699](https://github.rbx.com/Roblox/safety-platform-processors/pull/1699)),
the `storage-resources-demo-go` example, the in-repo Python example
(`pkg-python/eshotreload/`), and the libraries' design. Rows are tagged
`[C#]` / `[Go]` / `[Py]` / `[both]` (both C# and Go) / `[all]` (all three
languages).

## Failure-symptom table

| Symptom | Cause | Fix |
| --- | --- | --- |
| `[all]` Cluster has no credentials at runtime (`ForCluster` → `null` in C#; `ErrCredentialsNotFound` in Go; `CredentialsNotFoundError` in Python) | Cluster name mismatch across the code call, `managed_secrets.json`, and the ccgen Vault slug | Make them identical to the ccgen slug (e.g. `es-cs-cases-search`). See Step 1. |
| `[all]` No creds at all at startup (`active=0` logged in C#; every request 401/`ErrCredentialsNotFound` in Go; every request raises `CredentialsNotFoundError` in Python) | `EnableManagedCredentials: "true"` not deployed yet, OR creds were never provisioned (new service/cluster — Secrets Broker onboarding config not merged/active) | Land the deployment PR; for new services land the onboarding config (`provisioning-managed-credentials.md`); confirm `secretv2/.../elasticsearch_data/<cluster>` is populated |
| `[C#]` Credentials bind as empty dictionary; only `reason="startup"` ever logged | `Roblox.BEDEV2.Framework.Services.Http` older than `13.117.2` (doesn't auto-mount `managed_secrets.json`) | Bump the framework to `>= 13.117.2` |
| `[C#]` `ForCluster` → `null` / `InvalidOperationException: Elasticsearch client unavailable for cluster '<name>'` at startup, with a swallowed `TypeLoadException`/`MissingMethodException` from `Elastic.Transport` — **even though creds ARE present** | **Only on the legacy `1.1.*` library**, which is hard-bound to `Elastic.Transport 0.4.x` (`Elastic.Clients.Elasticsearch` `8.13`–`8.15` only); a `8.16`+ client fails to build at runtime and the per-cluster fallback swallows it. NuGet restores cleanly, so it masquerades as a credentials problem. | **Upgrade to `Roblox.RobloxElasticsearchClient` `2.0.*`**, which carries no `Elastic.Transport` dependency and has no version ceiling — then use any client version. (If you must stay on 1.x for now, pin `Elastic.Clients.Elasticsearch` to `8.15.x`.) See `csharp-library-recipe.md` §1 |
| `[C#]` Nomad deploy fails: `error parsing env template: key characters must be [A-Za-z0-9_.] but found '-'` | You put the hyphenated `ElasticsearchClusters__<cluster>__Urls__0` key inside a `template { env = true }` block, which consul-template parses (hyphens rejected) | Move it to the literal `env { }` block, which Nomad parses directly and accepts hyphens. Define the full config key there — no `Program.cs`/`AddInMemoryCollection` bridge. See `deployment-recipe.md` §3 |
| `[C#]` Service 401-storms after a Vault rotation | Still on static env-var creds; library not wired, or you cached the client | Confirm `IElasticsearchClientProvider.ForCluster` is called **per request**, not cached in a field |
| `[Go]` Rotation doesn't take effect / stale creds | The `Store` wasn't `Start`ed, was started with a request-scoped ctx that got cancelled, or `MANAGED_SECRETS_PATH` points at the wrong file | Start once with `context.Background()` at process startup — `eshotreload.NewStartedStore(ctx, log)` collapses this into one call and resolves the path via `eshotreload.ManagedSecretsPath()` (env override → in-container/local-dev fallback chain). If you must wire `NewStore` by hand, pass `eshotreload.ManagedSecretsPath()` — not the bare `CCGenDefaultPath` constant, which misses the in-container `/secrets/...` bind-mount layout |
| `[Go]` `ErrCredentialsNotFound` only in the container (works under `make run-local`) | Path was wired to the bare `eshotreload.CCGenDefaultPath` constant (relative `secrets/ccgen/managed_secrets.json`). In-container the cwd is `/app` and ccgen lands the file at the absolute `/secrets/ccgen/managed_secrets.json`, so the relative path resolves to nothing | Switch to `eshotreload.NewStartedStore` (or `eshotreload.ManagedSecretsPath()` if you must build the `*Store` by hand). Both apply the env override and fall back to `ResolveCCGenPath(CCGenDefaultPaths)`, which tries the absolute path when the relative one doesn't exist |
| `[Go]` `Authorization` header sent twice / auth errors | An `eshotreload.Transport` was passed as `cfg.Transport` | Pass only your own base `http.RoundTripper` (TLS/OTel) as `cfg.Transport`; the wrapper layers the injector on top |
| `[Go]` Credentials still read from env, not rotating | Left `Username`/`Password`/`APIKey` set on `elasticsearch.Config` | Remove them; the store is the source of truth and the wrapper strips them |
| `[Py]` `ImportError: eshotreload.es8 requires 'elasticsearch>=8'` (or the ES7 variant) at import time | Installed `roblox-eshotreload` without the client-specific extra | `pip install "roblox-eshotreload[es8]"` (or `[es7]`) matching the `elasticsearch-py` major version the service already pins. Never install both extras into the same interpreter — the ES7 and ES8 client pins are mutually incompatible |
| `[Py]` `ValueError: eshotreload.es8: static auth kwargs are not allowed alongside a hot-reload store (got ['basic_auth'])` at `new_client(...)` | Left `basic_auth=` / `api_key=` / `http_auth=` / `bearer_auth=` on the call — same idea as `Username`/`Password` on `elasticsearch.Config` in Go | Delete the static auth kwarg. The store is the source of truth; the wrapper installs the `Authorization` header itself on every request |
| `[Py]` Rotation doesn't take effect / stale creds; `on_reload` callback never fires | `Store` was constructed by hand and never `.start()`ed, or the store was pointed at the wrong path (relative `secrets/ccgen/...` from the wrong cwd) | Use `new_started_store()` (or `shared_started_store()` for multi-client processes); both call `.start()` and resolve the path via `managed_secrets_path()` (env override → local-dev/in-container fallback). If you must build the store by hand, pass `managed_secrets_path()` — not the bare `CCGEN_DEFAULT_PATH` constant, which misses the in-container `/secrets/...` bind-mount layout |
| `[Py]` `CredentialsNotFoundError` only in the container (works under `python -m pytest` locally) | Wired the store to the bare `CCGEN_DEFAULT_PATH` constant (relative `secrets/ccgen/managed_secrets.json`). In-container the cwd is `/app` and ccgen lands the file at the absolute `/secrets/ccgen/managed_secrets.json`, so the relative path resolves to nothing | Switch to `new_started_store()` (or `managed_secrets_path()` if you must build the `Store` by hand). Both apply the env override and fall back to `resolve_ccgen_path(CCGEN_DEFAULT_PATHS)`, which tries the absolute path when the relative one doesn't exist |
| `[Py]` `Authorization` header sent twice / auth errors / stale header wins | Passed a `node_class` / `connection_class` that already applies auth (e.g. a subclass of `Urllib3HttpNode` that layers in a static header), so the wrapper's per-request injector fights it | Give the wrapper a plain transport base (TLS, retries, OTel — no auth); the wrapper subclasses **your** class and installs the `Authorization` header on every call. Never pre-populate `Authorization` on a headers dict handed to the wrapper — it will be overwritten silently |
| `[Py]` `shared_started_store()` retains state between tests, or an initial-load error keeps raising | The singleton is process-wide by design; it captures a load failure and re-raises on every subsequent call so no service silently runs without credentials | Prefer `new_started_store()` in production code and a per-test `Store(tmp_path).start()` in tests. Do **not** try to reset `_SHARED_STORE`/`_SHARED_ERROR` — that's a private impl detail and would defeat the safety guarantee |
| `[C#]` `reason="credentials-changed"` never appears after rotation, only `startup` | Creds aren't flowing through `managed_secrets.json` (wrong cluster name / flag not set) | Re-check Step 1 + `EnableManagedCredentials` |
| `[C#]` URL change doesn't take effect without restart | Expected when the URL is a plain env var (snapshotted at process start) | Fine for static per-env URLs. If live URL rotation is genuinely required, switch to the JSON-template approach (`AddJsonFile(reloadOnChange: true)`) |
| `[C#]` Build error: `ElasticsearchClusterStaticConfig` not found | Missing `using Roblox.RobloxElasticsearchClient.Models;` (Path B only) | Add the using |
| `[C#]` Tests NRE / can't construct handler | Test still passes a raw `ElasticsearchClient` | Fake `IElasticsearchClientProvider` and return an in-memory client from `ForCluster` |
| `[C#]` Deleting the old factory/settings file breaks a *different* project's build or Docker image | The file is shared — another `.csproj` pulls it in via `<Compile Include="../.../Factory.cs">`, a sibling Dockerfile `COPY`s it, or other code uses a non-credential type it defines (settings POCO, a constant like `DefaultSearchPageSize`) | Before deleting, grep the whole repo (`*.csproj`, `*.cs`, `Dockerfile*`) for the file and its types. If shared, handle it in the same PR: move the non-credential parts to a shared/own file, or migrate the other consumer too — don't delete blindly. Verify with a full-solution + Docker build. See recipe §6 |
| `[all]` Component / integration (docker-compose) tests: health check passes but **every** ES-backed test fails with HTTP 500 / "Server Error" and an empty body | `docker-compose` `depends_on` waits only for container *start*, not readiness. The index/fixture seeder races Elasticsearch startup (ES 7.x needs ~20–40s) and creates no index, and/or the test host queries before fixtures are indexed. Timing-dependent → "fails on almost every PR." **Not** caused by the credential change (inert without `managed_secrets.json`). | Fix the harness in the same PR: seeder waits on `/_cluster/health?wait_for_status=yellow` and bulk-loads with `refresh=wait_for` under `set -eu`; test setup polls the real query path until the seeded doc returns before any test runs. Never rely on `depends_on` alone. See SKILL "Verification → Run the service's component / integration tests" |

## Caching rules differ by language (important)

The libraries don't share a single caching rule, so don't carry a C# habit into
Go or Python (or vice versa):

- **`[C#]` Never cache the client.** `IElasticsearchClientProvider.ForCluster`
  returns the *current* client; on rotation the library builds a fresh
  `ElasticsearchClient`, atomically swaps it in, and retires the old one after a
  grace period (default 5 min). Stashing the result in a field pins the old
  client and you never see rotated creds. Resolve per call — it's cheap.
- **`[Go]` Do build the client once and reuse it.** The `*elasticsearch.Client`
  is long-lived; rotation happens *inside* it because the `eshotreload.Transport`
  reads fresh credentials from the store on every request. Rebuilding the client
  per request would throw away the connection pool. Build once at startup, share
  it.
- **`[Py]` Do build the client once and reuse it (same as Go).** The
  `elasticsearch.Elasticsearch` client is long-lived; rotation happens *inside*
  it because the wrapper's transport (an `elastic_transport.Node` subclass on
  v8, an `elasticsearch.connection.Urllib3HttpConnection` subclass on v7) reads
  fresh credentials from the store on every request. Rebuilding the client per
  request throws away the connection pool and defeats the point. Build once at
  startup, share it (via a module-level singleton or a DI container).

The shared principle is the same — the credential is resolved at request time —
but in C# the per-request resolution is `ForCluster`, while in Go and Python
it's hidden in the transport and the client itself is stable.

## Authentication precedence (for sanity-checking Vault data)

Per cluster in `managed_secrets.json`:

| `api_key` set | `username`+`password` set | Result |
| --- | --- | --- |
| yes | (any) | API-key auth (`api_key` wins) |
| no | yes | Basic auth |
| no | no | No auth: cluster skipped in C# (`ForCluster` → `null`, warning); in Go the request goes out with no `Authorization` header; in Python the wrapper strips any pre-existing `Authorization` header and the request goes out unauthenticated |

If a cluster unexpectedly has no creds, check that exactly one auth tuple is
populated at the Vault path. All three libraries pick `api_key` over basic when
both are present.

## Verifying hot-reload end-to-end

### `[Go]`

1. Start the `Store` with a real `*slog.Logger` so reload events are visible.
2. Confirm a request succeeds at startup (creds loaded from the file).
3. Rotate the Vault secret (or edit the local `managed_secrets.json` fixture);
   `fsnotify` picks up the rewrite (debounced ~250 ms) and the **next** request
   uses the new credential — no restart, same client, same pool.
4. If a request fails with `ErrCredentialsNotFound`, the cluster name or the flag
   is wrong — see the symptom table.

### `[Py]`

1. Start the `Store` via `new_started_store()` (which calls `.start()` for you).
   The library logs at `INFO` under the `eshotreload.store` logger — make sure
   the service's logging config lets that through (`logging.basicConfig(level=INFO)`
   or an equivalent handler on `eshotreload`).
2. Confirm a request succeeds at startup — expect a log line like
   `loaded managed secrets: elasticsearch[<cluster>=<username>]`.
3. Rotate the Vault secret (or edit the local `managed_secrets.json` fixture);
   `watchdog` picks up the rewrite (debounced ~250 ms) and the **next** request
   uses the new credential. Expect a log line like
   `reloaded managed secrets: elasticsearch[<cluster>=<new-username>]`. The
   username flipping is the unambiguous signal that hot-reload happened; a
   custom callback registered via `store.on_reload(...)` also fires at this
   point (same watcher thread as the reload).
4. If a request raises `CredentialsNotFoundError`, the cluster name or the flag
   is wrong — see the symptom table.
5. Managed credentials keep the previous username valid for ~37 days after
   rotation, so a plain ping/search succeeds on either credential and can't
   tell you which one is live. For definitive proof, call
   `es.security.authenticate()` before and after the rotation: the returned
   `username` flips from the old value to the new one once the wrapper's
   transport observed the reload.

### `[C#]`

1. **At startup**, confirm the bind worked:
   ```
   ES clients rebuilt: reason="startup" active=1 added=1 rebuilt=0 ...
   ```
   `active=1` (or however many clusters) means config + creds bound. `active=0`
   means a wiring problem — go back to the symptom table.

2. **Trigger a rotation** (or have the storage team rotate the Vault secret).
   Within ~1s of the file rewrite you should see:
   ```
   ES cluster "<name>": previous client retired, will dispose at <ts> (grace=300s) reason="rebuilt"
   ES clients rebuilt: reason="credentials-changed" active=1 rebuilt=1 retired=1 ...
   ```
   This is proof the running service picked up new credentials with no restart.

3. **(Optional) prove *which* credential is live**, not just that *a* credential
   works. A plain ping/search succeeds on **either** credential, because the old
   one stays valid for ~37 days after rotation — so it can't tell you the swap
   happened. For definitive proof, call Elasticsearch's `_security/_authenticate`
   (NEST `client.Security.AuthenticateAsync()`, ES8
   `client.Security.AuthenticateAsync()`) before and after the rotation: managed
   credentials mint a **new, timestamped username** each rotation, so the returned
   `username` **flips** from the old value to the new one once the library rebuilt
   the client. (The in-repo examples expose this as a `GET /es/whoami/{cluster}`
   endpoint.) The username changing is the unambiguous signal that the running
   client is now authenticating with the rotated credential.

If `reason="static-config-changed"` shows up, that's a URL/timeout change
(the JSON-template URL source) reloading — also expected and harmless.
