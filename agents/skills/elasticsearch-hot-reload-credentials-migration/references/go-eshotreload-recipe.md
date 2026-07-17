# Go Recipe — `eshotreload` (code side)

The code change for adopting `eshotreload` in a Go service. Apply after Step 0
confirmed the service uses `go-elasticsearch` (v7 or v8) and Step 1 established
the cluster name.

Unlike C#, **there is no client-version gate**: `eshotreload` injects
credentials beneath the client via an `http.RoundTripper`, so a `v7` service
adopts without a rewrite. Pick the wrapper module that matches your
`go-elasticsearch` major version.

Worked example to mirror (in-repo demo, not yet a production customer — validate
carefully): `storage-resources-demo-go` →
`services/storage-resources-demo-go/internal/clients/clients.go`.

## Table of contents

1. Pick + install the wrapper module
2. Start the store once at startup
3. Build the long-lived client
4. Remove the old static credentials
5. Non-`elasticsearch` providers (RaaS, …)
6. Layering custom transports (TLS, OTel, retries)
7. Errors & tests

---

## 1. Pick + install the wrapper module

The library is published as independent modules; the wrapper pulls the core in
transitively (you don't `go get` the core separately):

| Your client | Module to install |
| --- | --- |
| `github.com/elastic/go-elasticsearch/v8` | `.../pkg/eshotreload/v8` |
| `github.com/elastic/go-elasticsearch/v7` | `.../pkg/eshotreload/v7` |

```bash
# v8
go get github.rbx.com/roblox/storage-resources-demo-go/pkg/eshotreload/v8
# or v7
go get github.rbx.com/roblox/storage-resources-demo-go/pkg/eshotreload/v7
```

Import the core (for `NewStartedStore`/`ManagedSecretsPath`/sentinel errors)
and the wrapper (aliased):

```go
import (
    elasticsearch "github.com/elastic/go-elasticsearch/v7" // or /v8
    "github.rbx.com/roblox/storage-resources-demo-go/pkg/eshotreload"
    esh "github.rbx.com/roblox/storage-resources-demo-go/pkg/eshotreload/v7" // or /v8
)
```

## 2. Start the store once at startup

The `Store` watches `managed_secrets.json` via `fsnotify` and holds the current
credentials behind an atomic snapshot. Start it **once per process** with a
lifetime context — the watcher goroutine should live for the whole process.

For the common case, use the one-liner. It resolves the path correctly for both
local-dev (cwd = service dir) and in-container (cwd = `/app`, secrets bind-
mounted at `/secrets/`) layouts, honors the `MANAGED_SECRETS_PATH` env override,
and tolerates a missing file at boot (logged warning; the watcher picks the file
up if ccgen drops it later):

```go
store, err := eshotreload.NewStartedStore(context.Background(), slogLogger /* or nil */)
if err != nil {
    return fmt.Errorf("eshotreload start: %w", err)
}
```

If the process wires multiple credentialed clients (ES, ClickHouse, RaaS, …) and
should share one watcher, use the process-wide singleton instead — it returns
the same `*Store` on every call so you don't spin up an `fsnotify` watcher per
caller. The singleton is bound to `context.Background()`; if you need lifecycle
control (e.g. test teardown), use `NewStartedStore` directly.

```go
store, err := eshotreload.SharedStartedStore(slogLogger)
```

> Only drop down to `NewStore` + `Start` when you genuinely need a custom path
> or store lifetime. The two-step form remains supported; the helpers exist to
> remove the boilerplate every consuming service used to repeat.

Pass a real `*slog.Logger` (not `nil`) if you want to see reload events in logs —
useful for verifying hot-reload after deploy.

> **Path resolution detail.** The package exposes a three-layer API; pick
> the highest one that fits the call site:
>
> 1. `eshotreload.NewStartedStore(ctx, log)` — builds + starts the `Store` at
>    `ManagedSecretsPath()`. The recommended entry point.
> 2. `eshotreload.ManagedSecretsPath()` — returns the resolved path string
>    (checks `MANAGED_SECRETS_PATH` first, otherwise calls
>    `ResolveCCGenPath(CCGenDefaultPaths)`). Use this when you must build the
>    `Store` by hand (custom logger plumbing, non-default lifecycle) but want
>    the same path semantics as `NewStartedStore` — including the env
>    override that operators rely on for fixtures.
> 3. `eshotreload.ResolveCCGenPath(candidates)` — the lower-level resolver:
>    returns the first existing entry from `candidates`, with no env
>    handling. Only reach for it directly when you're composing a non-default
>    candidate list; otherwise prefer `ManagedSecretsPath()`, which already
>    feeds `CCGenDefaultPaths` to it.
>
> Avoid the bare `eshotreload.CCGenDefaultPath` constant when wiring a store
> path by hand — it only matches the local-dev cwd layout and silently
> misses the absolute `/secrets/...` bind-mount the docker driver uses
> in-container.

## 3. Build the long-lived client

Construct the ES client **once** and reuse it. The wrapper installs an
`eshotreload.Transport` that looks up credentials from the store on every
request. **Do not** set `Username`/`Password`/`APIKey` on the config — the store
is the source of truth and the wrapper strips them.

```go
es, err := esh.NewClient(store, "es-cs-cases-search", elasticsearch.Config{
    Addresses:     []string{address}, // built in code; see below
    MaxRetries:    5,
    RetryOnStatus: []int{502, 503, 504, 429},
})
if err != nil {
    return err
}
// Use es normally; credentials hot-reload between requests, the connection
// pool is preserved, and in-flight work is not interrupted.
```

The cluster name (`"es-cs-cases-search"`) must match a key under the
`elasticsearch` provider in `managed_secrets.json` (Step 1). A mismatch surfaces
as `eshotreload.ErrCredentialsNotFound` on the next request.

### URL/address (no `IConfiguration`, no hyphen gotcha)

Go builds the address itself, so the C# env-var-bridge problem doesn't exist.
Read a plain env var, or derive per datacenter. The in-repo example does both —
`ES_ADDRESS` overrides everything (handy for local `https://localhost:9200`),
otherwise it builds `https://<cluster>-<dc>.<domain>` from `ES_DATACENTER`:

```go
address := os.Getenv("ES_ADDRESS")
if address == "" {
    dc := os.Getenv("ES_DATACENTER") // e.g. "sitetest3", "chi1"
    // map dc -> base domain (sitetest -> simulpong.com, prod -> simulprod.com),
    // reject unknown values so a typo can't route at the wrong env, then:
    address = "https://" + cluster + "-" + dc + "." + domain
}
```

Keep whatever address convention the service already uses; only the credential
wiring is changing.

## 4. Remove the old static credentials

> **Greenfield:** skip this section — there are no static credential paths to
> remove. Just build the client as in §3 (no `Username`/`Password`/`APIKey` on
> `elasticsearch.Config`); the store is the only credential source from the start.

Delete the code paths that read ES username/password/API key from env and feed
them into `elasticsearch.Config`. After this change the only credential source
is the store.

```go
// before
cfg := elasticsearch.Config{
    Addresses: []string{addr},
    Username:  os.Getenv("ES_USERNAME"),
    Password:  os.Getenv("ES_PASSWORD"),
}
client, _ := elasticsearch.NewClient(cfg)

// after
es, _ := esh.NewClient(store, cluster, elasticsearch.Config{Addresses: []string{addr}})
```

Remove the now-dead `ES_USERNAME`/`ES_PASSWORD` (or equivalents) from the
service's env/config struct too; they're replaced by `managed_secrets.json`
(handled deployment-side in `deployment-recipe.md`).

## 5. Non-`elasticsearch` providers (RaaS, …)

If the resource is registered under a different provider in
`managed_secrets.json` (e.g. `raas`), build a provider and use
`NewClientWithProvider`:

```go
provider := eshotreload.GenericProvider(store, eshotreload.ProviderRaas, "my-resource")
es, err := esh.NewClientWithProvider(provider, elasticsearch.Config{
    Addresses: []string{"https://my-raas-endpoint.example.com"},
})
```

## 6. Layering custom transports (TLS, OTel, retries)

Set `cfg.Transport` to your own `http.RoundTripper`; the wrapper installs it as
the **base** transport beneath the credential injector, so OTel spans / custom
TLS / retry middleware still apply:

```go
es, err := esh.NewClient(store, cluster, elasticsearch.Config{
    Addresses: []string{address},
    Transport: otelhttp.NewTransport(http.DefaultTransport),
})
```

**Do not** pass an `eshotreload.Transport` as `cfg.Transport` — that would
double-inject the `Authorization` header.

## 7. Errors & tests

Sentinel errors are wrapped — check with `errors.Is`:

- `eshotreload.ErrNoProvider`
- `eshotreload.ErrProviderNotFound`
- `eshotreload.ErrCredentialsNotFound`

`ErrCredentialsNotFound` on the next request after deploy almost always means the
cluster name doesn't match the `managed_secrets.json` key, or
`EnableManagedCredentials` isn't on yet (see `gotchas.md`).

For tests, point the store at a temp `managed_secrets.json` fixture (the schema
in `gotchas.md`) via `NewStore(tmpPath, nil)` and assert the client builds and a
request carries the expected auth — mirror `clients_test.go` /
`pkg/eshotreload/v7/client_test.go` in `storage-resources-demo-go`.
