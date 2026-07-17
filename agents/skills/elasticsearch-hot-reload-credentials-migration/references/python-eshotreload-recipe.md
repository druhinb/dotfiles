# Python Recipe — `roblox-eshotreload` (code side)

The code change for adopting `roblox-eshotreload` in a Python service. Apply
after Step 0 confirmed the service uses `elasticsearch-py` (v7 or v8) and
Step 1 established the cluster name.

The Python library is a line-for-line port of the Go package — same
`managed_secrets.json` schema, same cluster-name join key, same auth
precedence, same 250 ms debounce, same "start the store once, build the
client once, credentials rotate per request" contract.

Unlike C#, **there is no client-version gate**: the wrapper installs a
per-request seam (an `elastic_transport.Node` subclass for v8, an
`elasticsearch.connection.Urllib3HttpConnection` subclass for v7) that reads
the freshest credentials from the store on every call, so a v7 service adopts
without a rewrite. Pick the extra that matches your `elasticsearch-py` major
version.

Worked example to mirror (in-repo demo, not yet a production customer —
validate carefully): `storage-resources-demo` →
`pkg-python/eshotreload/examples/query_loop.py`.

## Table of contents

1. Pick + install the extra
2. Start the store once at startup
3. Build the long-lived client
4. Remove the old static credentials
5. Non-`elasticsearch` providers (RaaS, ClickHouse, …)
6. Layering custom transports (TLS, retries, OTel)
7. Errors & tests

---

## 1. Pick + install the extra

The distribution name is `roblox-eshotreload`; the client-version wrapper is
gated behind an extra so the core install pulls no `elasticsearch-py` version
of its own:

| Your client                              | Install command                          |
| ---------------------------------------- | ---------------------------------------- |
| `elasticsearch>=8` (`elasticsearch-py 8.x`) | `pip install "roblox-eshotreload[es8]"` |
| `elasticsearch>=7,<8` (`elasticsearch-py 7.x`) | `pip install "roblox-eshotreload[es7]"` |
| Store + transport helpers only (custom client) | `pip install roblox-eshotreload`         |

Add the pinned distribution to the service's `pyproject.toml` /
`requirements.txt` alongside your existing `elasticsearch` dep — the extra is
declarative, the wrapper is imported by the ES-major-version-specific
sub-package:

```python
from eshotreload import new_started_store
from eshotreload.es8 import new_client   # or eshotreload.es7
```

The two sub-packages are import-guarded: `import eshotreload.es8` raises a
clear `ImportError` telling you to install the `[es8]` extra if the underlying
`elasticsearch>=8` isn't installed. Never install both extras into the same
interpreter — the ES7 and ES8 client wheels have conflicting pins on
`elasticsearch`, they can't coexist.

## 2. Start the store once at startup

The `Store` watches `managed_secrets.json` via `watchdog` and holds the current
credentials behind an atomic snapshot. **Start it once per process** at
startup, not per request.

For the common case, use the one-liner. It resolves the path correctly for
both local-dev (cwd = service dir) and in-container (cwd = `/app`, secrets
bind-mounted at `/secrets/`) layouts, honors the `MANAGED_SECRETS_PATH` env
override, and tolerates a missing file at boot (logged warning; the watcher
picks the file up if ccgen drops it later):

```python
from eshotreload import new_started_store

store = new_started_store()   # pass a logger if you have one you want it to use
```

If the process wires multiple credentialed clients (ES + ClickHouse + RaaS,
etc.) and should share one watcher, use the process-wide singleton instead —
it returns the same `Store` on every call so you don't spin up a watcher per
caller:

```python
from eshotreload import shared_started_store

store = shared_started_store()
```

Tests should prefer `new_started_store` per test (the singleton can't be reset
between test cases and an initial-load error would leak across tests).

Optionally register a callback to react to rotations (metrics, log line,
cache invalidation, etc.). Callbacks run on the watcher thread — keep them
cheap; spawn a thread if you need to block:

```python
store.on_reload(lambda: log.info("credentials rotated"))
```

The library itself already logs each successful reload at `INFO` under the
`eshotreload.store` logger (`loaded managed secrets: elasticsearch[<cluster>=<username>]`
and later `reloaded managed secrets: …`), so the callback is optional signal,
not the primary one.

> **Path resolution detail.** The package exposes a three-layer API; pick
> the highest one that fits the call site:
>
> 1. `new_started_store(logger=None)` — builds + starts the `Store` at
>    `managed_secrets_path()`. The recommended entry point.
> 2. `managed_secrets_path()` — returns the resolved path string
>    (`MANAGED_SECRETS_PATH` env var if set, otherwise the first existing
>    entry in `CCGEN_DEFAULT_PATHS`). Use this when you must build the `Store`
>    by hand (custom logger plumbing, non-default lifecycle) but want the same
>    path semantics as `new_started_store` — including the env override that
>    operators rely on for fixtures.
> 3. `resolve_ccgen_path(candidates)` — the lower-level resolver: returns
>    the first existing entry from `candidates`, with no env handling. Only
>    reach for it directly when you're composing a non-default candidate list.
>
> Avoid the bare `CCGEN_DEFAULT_PATH` constant when wiring a store path by
> hand — it only matches the local-dev cwd layout and silently misses the
> absolute `/secrets/...` bind-mount the docker driver uses in-container.
> Use `CCGEN_DEFAULT_PATHS` (plural, the tuple) or `managed_secrets_path()`.

## 3. Build the long-lived client

Construct the ES client **once** and reuse it. The wrapper installs a
per-request seam (an `elastic_transport.Node` subclass for v8; an
`elasticsearch.connection.Urllib3HttpConnection` subclass for v7) that looks
up credentials from the store on every request. **Do not** set static auth
kwargs on the client — the wrapper rejects them at construction time (the
store is the single source of truth, and mixing the two only creates
ambiguity about which credentials win on a given request).

### v8 (`elasticsearch-py` 8.x)

```python
from eshotreload.es8 import new_client

es = new_client(
    store,
    cluster="es-cs-cases-search",
    hosts=[address],           # built in code; see below
    request_timeout=5,
    max_retries=5,
    retry_on_status=(502, 503, 504, 429),
)

# Use `es` normally; credentials hot-reload between requests, the connection
# pool is preserved, and in-flight work is not interrupted.
info = es.info()
```

### v7 (`elasticsearch-py` 7.x)

```python
from eshotreload.es7 import new_client

es = new_client(
    store,
    cluster="es-cs-cases-search",
    hosts=[address],
    request_timeout=5,
    max_retries=5,
)
```

The cluster name (`"es-cs-cases-search"`) must match a key under the
`elasticsearch` provider in `managed_secrets.json` (Step 1). A mismatch
surfaces as `eshotreload.CredentialsNotFoundError` wrapped in the client's
per-request error on the next call.

**Rejected static auth kwargs** — the wrapper will raise `ValueError` at
`new_client` time if any of these appear in `**client_kwargs`:

- v8: `basic_auth`, `api_key`, `bearer_auth`, `http_auth`.
- v7: `http_auth`, `api_key`.

Delete them from the call site; they're what the store replaces.

### URL/address (no `IConfiguration`, no hyphen gotcha)

Like Go, Python builds the address itself, so the C# env-var-bridge problem
doesn't exist. Read a plain env var, or derive per datacenter. Keep whatever
convention the service already uses; only the credential wiring is changing:

```python
address = os.environ.get("ES_ADDRESS")
if not address:
    dc = os.environ["ES_DATACENTER"]   # e.g. "sitetest3", "chi1"
    # map dc -> base domain (sitetest -> simulpong.com, prod -> simulprod.com),
    # reject unknown values so a typo can't route at the wrong env, then:
    address = f"https://{cluster}-{dc}.{domain}"
```

## 4. Remove the old static credentials

> **Greenfield:** skip this section — there are no static credential paths to
> remove. Just build the client as in §3 (no static auth kwargs); the store is
> the only credential source from the start.

Delete the code paths that read ES username / password / API key from env and
feed them into `Elasticsearch(...)`. After this change the only credential
source is the store.

```python
# before
es = Elasticsearch(
    hosts=[address],
    basic_auth=(os.environ["ES_USERNAME"], os.environ["ES_PASSWORD"]),
)

# after
es = new_client(store, "es-cs-cases-search", hosts=[address])
```

Remove the now-dead `ES_USERNAME` / `ES_PASSWORD` (or equivalents) from the
service's env/config module too; they're replaced by `managed_secrets.json`
(handled deployment-side in `deployment-recipe.md`).

## 5. Non-`elasticsearch` providers (RaaS, ClickHouse, …)

If the resource is registered under a different provider in
`managed_secrets.json` (e.g. `raas`, `clickhouse`), build a provider and use
`new_client_with_provider` (v8) / `new_client_with_provider` (v7). Same store,
different provider name:

```python
from eshotreload import generic_provider
from eshotreload.es8 import new_client_with_provider

provider = generic_provider(store, "raas", "raas-myresource")
client = new_client_with_provider(provider, hosts=["https://raas.example.com"])
```

Or, if you're not talking to Elasticsearch at all, use the store directly:

```python
creds = store.get_credentials("raas", "raas-myresource")
```

The provider-name constants `PROVIDER_ELASTICSEARCH`, `PROVIDER_CLICKHOUSE`,
`PROVIDER_RAAS` are re-exported from the top-level package for reference —
prefer these over string literals.

## 6. Layering custom transports (TLS, retries, OTel)

The wrappers accept a base `node_class` (v8) or `connection_class` (v7); the
wrapper subclasses that base and layers the credential injector on top, so
custom TLS / OpenTelemetry / retry middleware still applies:

```python
# v8: pass any elastic_transport.BaseNode subclass
from elastic_transport import RequestsHttpNode
es = new_client(store, cluster, hosts=[address], node_class=RequestsHttpNode)

# v7: pass any elasticsearch.connection.Connection subclass
from my_infra.transport import TracingHttpConnection
es = new_client(store, cluster, hosts=[address], connection_class=TracingHttpConnection)
```

The `node_class` / `connection_class` must be a subclass of the client's
transport base — the wrapper subclasses **your** class, not the other way
around. Do **not** pass a node / connection that already applies auth: it will
be overwritten on every request by the credential injector, silently.

## 7. Errors & tests

Error types are exported from the top-level `eshotreload` package. Catch them
directly (they're proper exception classes, not sentinels):

- `eshotreload.EshotreloadError` — abstract base.
- `eshotreload.NoProviderError` — no provider registered under that name.
- `eshotreload.ProviderNotFoundError` — provider absent from the current
  snapshot (e.g. `managed_secrets.json` doesn't include an `elasticsearch`
  block yet).
- `eshotreload.CredentialsNotFoundError` — provider present but no entry for
  the requested resource/cluster. On the next request after deploy this
  almost always means the cluster name doesn't match the
  `managed_secrets.json` key, or `EnableManagedCredentials` isn't on yet (see
  `gotchas.md`).

For tests, point the store at a temp `managed_secrets.json` fixture (the
schema is documented in `gotchas.md`) via
`Store(tmp_path, logger=None).start()` and assert the client builds and a
request carries the expected `Authorization` header — mirror the tests under
`pkg-python/eshotreload/tests/` in `storage-resources-demo`.

```python
def test_hot_reload(tmp_path):
    secrets = tmp_path / "managed_secrets.json"
    secrets.write_text(json.dumps({
        "providers": [{
            "name": "elasticsearch",
            "config": {"es-cs-cases-search": {"username": "u1", "password": "p1"}},
        }],
    }))
    store = Store(str(secrets))
    store.start()
    try:
        es = new_client(store, "es-cs-cases-search", hosts=["http://es.test"])
        # assert against a recorded transport / responses fixture ...
    finally:
        store.stop()
```

Prefer `new_started_store` in production code and the raw `Store` in tests —
the singleton `shared_started_store` isn't test-safe (see §2).
