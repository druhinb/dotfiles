# C# Library Recipe (code side)

The code change for adopting `Roblox.RobloxElasticsearchClient` **2.0.0**. Apply
only after Step 0 confirmed the service is on a supported C# Elasticsearch client
(NEST/`Elasticsearch.Net` for ES7, or `Elastic.Clients.Elasticsearch` for ES8 —
**both are supported**) and Step 1 established the cluster name.

> **2.0.0 is generic over the client type.** The library carries **no
> Elasticsearch dependency** of its own and works with **any** client version
> (ES7 or ES8, any 7.x/8.x). You supply a tiny `ElasticsearchClientBuilder<TClient>`
> delegate (~15 lines) that constructs the concrete client; the library does the
> bind / diff / atomic-swap / graceful-dispose. This removes the 1.x ceiling
> (1.x was hard-bound to `Elastic.Transport 0.4.x`, i.e. `Elastic.Clients.Elasticsearch`
> `8.13`–`8.15` only). There is **no version pin to manage anymore** — see §1.

The public surface you'll touch (`TClient` is *your* client type —
`Elastic.Clients.Elasticsearch.ElasticsearchClient` for ES8, `Nest.ElasticClient`
for ES7):

- `services.AddRobloxElasticsearchClients<TClient>(Configuration, BuildClient)` —
  from `Roblox.RobloxElasticsearchClient.DependencyInjection`. Registers
  everything; `BuildClient` is your `ElasticsearchClientBuilder<TClient>`.
- `IElasticsearchClientProvider<TClient>` — from `Roblox.RobloxElasticsearchClient`.
  Inject it; call `.ForCluster("<name>")` which returns `TClient?` (null if that
  cluster isn't currently configured).
- `ElasticsearchClientBuilder<TClient>` — the delegate you implement (see §1.5).
  This is the **only** version-specific code in the whole adoption.
- `ElasticsearchClusterStaticConfig` / `ElasticsearchClusterCredentials` — from
  `Roblox.RobloxElasticsearchClient.Models`. The builder receives both;
  `ElasticsearchClusterStaticConfig` has `string[] Urls` and an
  `int RequestTimeoutSeconds` that **defaults to 30s** (leave it unset — see the
  note below). The explicit-static-config dictionary (Path B) uses the same POCO.

> **Don't set `RequestTimeoutSeconds` as part of this migration.** It defaults to
> 30s (which is also the Elastic v8 client's own default), so setting it to `30`
> is a literal no-op, and it has nothing to do with credentials. Omit it
> everywhere (env block, `appsettings.json`, Path B config). The *only* reason to
> set it is to **preserve a non-default timeout** the service's old client used —
> if the old factory passed e.g. `TimeSpan.FromSeconds(60)`, carry that over as
> `RequestTimeoutSeconds = 60` so behavior doesn't silently change. The library
> applies it once at client-build time via `ElasticsearchClientSettings.RequestTimeout`.

## Table of contents

1. `.csproj` changes
1.5. The client builder (the one version-specific piece)
2. Choosing Path A vs Path B
3. `Startup.cs` — register the library
4. The query call site — resolve per call
5. `appsettings.json` / `Settings.cs`
6. Delete the dead factory
7. Tests

---

## 1. `.csproj` changes

Add the package at **`2.0.*`**, keep (or add) **your own** Elasticsearch client
reference at **whatever version you already use**, and ensure the framework is
new enough to auto-mount `managed_secrets.json` into `IConfiguration`
(**`>= 13.117.2`**; older versions silently bind an empty credentials dictionary).

**ES8** (`Elastic.Clients.Elasticsearch`):

```diff
   <ItemGroup>
     <PackageReference Include="Elastic.Clients.Elasticsearch" Version="8.17.1" />
+    <PackageReference Include="Roblox.RobloxElasticsearchClient" Version="2.0.*" />
-    <PackageReference Include="Roblox.BEDEV2.Framework.Services.Http" Version="13.111.2" />
+    <PackageReference Include="Roblox.BEDEV2.Framework.Services.Http" Version="13.118.2" />
   </ItemGroup>
```

**ES7** (NEST — the existing `<PackageReference Include="NEST" Version="7.17.5" />`
stays exactly as-is; `Elasticsearch.Net` services keep their low-level client ref):

```diff
   <ItemGroup>
     <PackageReference Include="NEST" Version="7.17.5" />
+    <PackageReference Include="Roblox.RobloxElasticsearchClient" Version="2.0.*" />
-    <PackageReference Include="Roblox.BEDEV2.Framework.Services.Http" Version="13.111.2" />
+    <PackageReference Include="Roblox.BEDEV2.Framework.Services.Http" Version="13.118.2" />
   </ItemGroup>
```

> **No client-version pin to manage.** 2.0.0 carries **no** Elasticsearch /
> `Elastic.Transport` dependency, so there is no ABI ceiling — the 1.x trap (pin
> `8.15.x`, never `8.16`+) is **gone**. Your `.csproj` owns the client version
> directly: any 7.x (NEST/`Elasticsearch.Net`) or any 8.x
> (`Elastic.Clients.Elasticsearch`) works, because the version-specific code lives
> in *your* builder (§1.5), compiled against *your* chosen client. If the client
> version is pinned centrally (`Directory.Packages.props`), just leave it there and
> add a bare `<PackageReference Include="Roblox.RobloxElasticsearchClient" />`.

The library never references an Elasticsearch type — it knows the client only as
an opaque `TClient`. `ForCluster` returns that exact `TClient`
(`ElasticsearchClient` for ES8, `ElasticClient` for ES7), so your query code keeps
compiling against the client you already use.

## 1.5. The client builder (the one version-specific piece)

Every registration takes an `ElasticsearchClientBuilder<TClient>` — a delegate
that turns a cluster's (hot-reloaded) credentials + static config into a concrete
client. This ~15-line function is the **only** version-sensitive code in the whole
adoption, and it lives in *your* project against *your* client version. Put it in a
small static class (mirrors the two in-repo examples: ES8's `Es8ClientBuilder`,
ES7's `Es7NestClientBuilder`).

**ES8** — `Elastic.Clients.Elasticsearch`:

```csharp
using Elastic.Clients.Elasticsearch;
using Elastic.Transport;
using Roblox.RobloxElasticsearchClient;
using Roblox.RobloxElasticsearchClient.Models;

public static class Es8ClientBuilder
{
    public static readonly ElasticsearchClientBuilder<ElasticsearchClient> Instance = Build;

    public static ElasticsearchClient Build(
        string cluster,
        ElasticsearchClusterCredentials creds,
        ElasticsearchClusterStaticConfig cfg)
    {
        var settings = new ElasticsearchClientSettings(new Uri(cfg.Urls[0]))
            .RequestTimeout(TimeSpan.FromSeconds(cfg.RequestTimeoutSeconds))
            .DefaultIndex(cluster);

        settings = !string.IsNullOrEmpty(creds.ApiKey)
            ? settings.Authentication(new ApiKey(creds.ApiKey))
            : settings.Authentication(new BasicAuthentication(creds.Username!, creds.Password!));

        return new ElasticsearchClient(settings);
    }
}
```

**ES7** — NEST (`Nest.ElasticClient`):

```csharp
using Elasticsearch.Net;
using Nest;
using Roblox.RobloxElasticsearchClient;
using Roblox.RobloxElasticsearchClient.Models;

public static class Es7NestClientBuilder
{
    public static readonly ElasticsearchClientBuilder<ElasticClient> Instance = Build;

    public static ElasticClient Build(
        string cluster,
        ElasticsearchClusterCredentials creds,
        ElasticsearchClusterStaticConfig cfg)
    {
        var settings = new ConnectionSettings(new Uri(cfg.Urls[0]))
            .RequestTimeout(TimeSpan.FromSeconds(cfg.RequestTimeoutSeconds))
            .DefaultIndex(cluster);

        settings = !string.IsNullOrEmpty(creds.ApiKey)
            ? settings.ApiKeyAuthentication(new ApiKeyAuthenticationCredentials(creds.ApiKey))
            : settings.BasicAuthentication(creds.Username, creds.Password);

        return new ElasticClient(settings);
    }
}
```

**ES7** — low-level `Elasticsearch.Net` (`ElasticLowLevelClient` /
`IElasticLowLevelClient`), for services that never adopted NEST. Same shape, but
build from `ConnectionConfiguration` (not NEST's `ConnectionSettings`) and return
the low-level client:

```csharp
using Elasticsearch.Net;
using Roblox.RobloxElasticsearchClient;
using Roblox.RobloxElasticsearchClient.Models;

public static class Es7LowLevelClientBuilder
{
    public static readonly ElasticsearchClientBuilder<ElasticLowLevelClient> Instance = Build;

    public static ElasticLowLevelClient Build(
        string cluster,
        ElasticsearchClusterCredentials creds,
        ElasticsearchClusterStaticConfig cfg)
    {
        var config = new ConnectionConfiguration(new Uri(cfg.Urls[0]))
            .RequestTimeout(TimeSpan.FromSeconds(cfg.RequestTimeoutSeconds));

        config = !string.IsNullOrEmpty(creds.ApiKey)
            ? config.ApiKeyAuthentication(creds.ApiKey)            // base64 api-key form
            : config.BasicAuthentication(creds.Username, creds.Password);

        return new ElasticLowLevelClient(config);
    }
}
```

Then register/inject with `TClient = ElasticLowLevelClient` (or the interface,
`IElasticLowLevelClient` — either satisfies the `where TClient : class` constraint):
`AddRobloxElasticsearchClients<ElasticLowLevelClient>(Configuration, Es7LowLevelClientBuilder.Instance)`.

The engine, the hot-reload semantics, the tests — everything else is identical
regardless of which builder you pass. The only difference between an ES7 and an ES8
adoption is this file plus the `<TClient>` type argument at the registration and
injection sites.

> **Auth precedence:** `api_key` wins over basic auth when both are present
> (matches what the ccgen template emits — usually only one tuple is populated).
> **Build-failure safety:** the engine calls your builder inside a per-cluster
> try/catch, so throwing here keeps the *previous* client serving rather than
> taking the cluster down. **NEST disposal note:** `ElasticClient` is not
> `IDisposable` (its `ConnectionSettings` is), so a rotated-out NEST client is
> reclaimed by GC rather than disposed eagerly — harmless given the weekly rotation
> cadence and minutes-long grace window.

## 2. Choosing Path A vs Path B

Both paths produce the same `IElasticsearchClientProvider<TClient>` and both hot-reload
credentials. They differ only in **where the per-cluster static config (URLs,
timeout) comes from**.

| Use… | When | Static config source |
| --- | --- | --- |
| **Path A** (default) | Service binds config from `appsettings.json` / `IConfiguration`, or is happy to | `ElasticsearchClusters` section in config |
| **Path B** | Service already exposes ES URL through a typed `Settings.cs` hydrated by `Roblox.Configuration` from env vars, and you don't want to migrate that | A `Dictionary<string, ElasticsearchClusterStaticConfig>` you build from `Settings` and pass in |

Both reference PRs use **Path A**. Prefer it unless the service has an
established `Settings.cs` + env-var convention you'd rather not disturb (then
Path B avoids touching the deployment file's URL plumbing). Note the trade-off:
on Path B the static config does **not** hot-reload (URLs are fixed until
redeploy); credentials hot-reload on both paths.

---

## 3. `Startup.cs` — register the library (Path A)

Replace the hand-rolled client/factory registration with one call, passing the
builder from §1.5. (`ElasticsearchClient` shown — for ES7 use
`AddRobloxElasticsearchClients<ElasticClient>(Configuration, Es7NestClientBuilder.Instance)`.)

```diff
-using Elastic.Clients.Elasticsearch;
-using Elastic.Transport;
+using Elastic.Clients.Elasticsearch;
+using Roblox.RobloxElasticsearchClient.DependencyInjection;

 public void ConfigureServices(IServiceCollection services)
 {
     services.AddBEDEV2HttpServiceDefaults();
     // ... your other registrations ...

-    services.AddSingleton(sp =>
-    {
-        var settings = sp.GetRequiredService<IOptionsMonitor<ElasticsearchClientSettings>>().CurrentValue;
-        var clientSettings = new ElasticsearchClientSettings(new Uri(settings.Url));
-        clientSettings.Authentication(new BasicAuthentication(settings.Username, settings.Password));
-        return new ElasticsearchClient(clientSettings);
-    });
+    // Hot-reloading Elasticsearch client(s). Credentials are sourced from
+    // /secrets/ccgen/managed_secrets.json (rotated by Vault) and static config
+    // is bound from the "ElasticsearchClusters" section. The builder (Es8ClientBuilder)
+    // is the only version-specific code; the library stays client-agnostic.
+    services.AddRobloxElasticsearchClients<ElasticsearchClient>(Configuration, Es8ClientBuilder.Instance);
 }
```

### Path B variant

Keep your `Settings.cs` and pass the static config explicitly (the builder is
still the first argument after `Configuration`):

```csharp
using Elastic.Clients.Elasticsearch;
using Roblox.RobloxElasticsearchClient.DependencyInjection;
using Roblox.RobloxElasticsearchClient.Models;

var settings = Configuration.Get<Settings>();

services.AddRobloxElasticsearchClients<ElasticsearchClient>(
    Configuration,
    Es8ClientBuilder.Instance,
    staticConfig: new Dictionary<string, ElasticsearchClusterStaticConfig>
    {
        ["es-conversations"] = new()
        {
            Urls = new[] { settings.ElasticsearchUrl },
            // RequestTimeoutSeconds defaults to 30s — omit unless preserving a non-default timeout.
        },
    });
```

The dictionary key (`es-conversations`) must be the cluster name from Step 1.

---

## 4. The query call site — resolve per call

Inject `IElasticsearchClientProvider<TClient>` instead of the raw client, and
resolve **on every call**. The provider atomically swaps the client when creds
rotate; caching the returned reference defeats hot reload. (ES8 `ElasticsearchClient`
shown; ES7 is identical with `IElasticsearchClientProvider<ElasticClient>`.)

```diff
-using Elastic.Clients.Elasticsearch;
+using Elastic.Clients.Elasticsearch;
+using Roblox.RobloxElasticsearchClient;

 public class ElasticsearchAccessor : IElasticsearchAccessor
 {
-    private readonly ElasticsearchClient _client;
+    // Cluster name: must match the key in appsettings ElasticsearchClusters AND
+    // the provider config in /secrets/ccgen/managed_secrets.json (the ccgen slug).
+    private const string ClusterName = "es-cs-cases-search";
+    private readonly IElasticsearchClientProvider<ElasticsearchClient> _clientProvider;

-    public ElasticsearchAccessor(ElasticsearchClient client)
-    {
-        _client = client;
-    }
+    public ElasticsearchAccessor(IElasticsearchClientProvider<ElasticsearchClient> clientProvider)
+    {
+        _clientProvider = clientProvider ?? throw new ArgumentNullException(nameof(clientProvider));
+    }

     public async Task<SearchResponse<MyDoc>> SearchAsync(/* ... */)
     {
-        return await _client.SearchAsync<MyDoc>(/* ... */);
+        var client = _clientProvider.ForCluster(ClusterName);
+        if (client == null)
+        {
+            // Only happens if ElasticsearchClusters config or managed_secrets.json
+            // is missing this cluster. Surface as an error so the existing
+            // retry/DLQ path handles it instead of NRE-ing.
+            throw new InvalidOperationException(
+                $"Elasticsearch client unavailable for cluster '{ClusterName}'.");
+        }
+        return await client.SearchAsync<MyDoc>(/* ... */);
     }
 }
```

The returned `client` is the same client type you had before (`ElasticsearchClient`
for ES8, `ElasticClient` for ES7), so the actual query code (`SearchAsync`,
`IndexAsync`, `BulkAsync`, etc.) is unchanged.

---

## 5. `appsettings.json` / `Settings.cs`

### Path A — `appsettings.json`

Add the `ElasticsearchClusters` section. URLs here are dev/local defaults;
per-env values are overridden via the deployment file (see
`deployment-recipe.md`). Many services follow a "secrets go in Nomad" convention
and keep this minimal or omit dev URLs entirely — match the service's existing
convention rather than forcing a dev default in.

```json
{
  "ElasticsearchClusters": {
    "es-cs-cases-search": {
      "Urls": [ "https://es-cs-cases-search-sitetest3.simulpong.com" ]
    }
  }
}
```

(`RequestTimeoutSeconds` is intentionally omitted — it defaults to 30s. Add it
only to preserve a non-default timeout the old client used.)

If the service previously had an `ElasticsearchClientSettings` (singular,
`Url`/`Username`/`Password`) section, delete it.

### Path B — `Settings.cs`

Leave URL/env-var plumbing as-is; you read it in `Startup.cs` and pass it in.
Remove the username/password fields — credentials no longer come through
`Settings` (the library reads them from `managed_secrets.json`):

```diff
-    public string ElasticSearchUsername { get; set; } = Environment.GetEnvironmentVariable("ELASTIC_CLIENT_USER_USERNAME") ?? "";
-    public string ElasticSearchPassword { get; set; } = Environment.GetEnvironmentVariable("ELASTIC_CLIENT_USER_PASSWORD") ?? "";
     public string ElasticSearchUrl { get; set; } = Environment.GetEnvironmentVariable("ElasticSearchUrl") ?? "";
```

---

## 6. Delete the dead factory — but verify nothing else uses it first

> **Greenfield:** skip this section — there's no old factory to delete.

If the service had an `ElasticsearchClientFactory` (or similar) whose only job
was to construct the client from settings, delete it and its test file — the
library replaces it entirely. Don't leave it around "just in case"; a dead
factory that still reads credential env vars invites someone to wire it back up.

**Before you delete, confirm the file is actually dead.** In a monorepo the same
`.cs` file is often shared across services, so removing it can silently break a
*different* project's build or Docker image. Check all three of these:

1. **Cross-project `<Compile Include>` references.** Another project may pull this
   file in via a relative path. Grep every `.csproj`, not just this service's:

```bash
# from the repo root — find any project that compiles the file you want to delete
grep -rn "ElasticsearchClientFactory.cs" --include=*.csproj .
# and any code that references the types it defines (settings POCO, page-size const, etc.)
grep -rn "ElasticsearchClientFactory\|ElasticsearchClientSettings" --include=*.cs .
```

2. **Dockerfile `COPY` lines.** A sibling service's Dockerfile may `COPY` the file
   into its build context:

```bash
grep -rn "ElasticsearchClientFactory" --include=Dockerfile* .
```

3. **Shared types, not just the client.** Factories sometimes also hold unrelated
   config the file was a convenient home for (e.g. a settings POCO bound from
   config, a `DefaultSearchPageSize` constant). Other code may inject or read
   those even though they have nothing to do with credentials.

If the file is referenced only by this service, delete it. **If anything else
uses it, you must handle that in the same PR** — pick the lightest option:

- **Preserve the non-credential parts.** If a sibling project only needs a
  settings POCO / constant from the file (not the credential-reading client
  construction), move those into a small shared file (or that consumer's own
  project) and delete only the now-dead client-construction code.
- **Migrate the other consumer too.** If the sibling also constructs an ES client
  the old way, migrate it to the library in this PR as well.
- **Don't delete yet.** If untangling it is out of scope, leave the file in place,
  strip out only the credential-reading paths, and note the follow-up — a build
  that doesn't compile is worse than a slightly-late cleanup.

**Verify with a full build, not just this service:** build the whole solution (or
every affected project) and build the affected Docker images, so a broken
cross-project reference surfaces now instead of in CI.

---

## 7. Tests

Anywhere a test constructed the handler with a raw `ElasticsearchClient`, fake
the provider instead and have it return an in-memory client:

```diff
-    private ElasticsearchClient _client;
+    private IElasticsearchClientProvider<ElasticsearchClient> _clientProvider;

     public void SetUp()
     {
-        _client = CreateInMemoryEsClient();
+        _clientProvider = A.Fake<IElasticsearchClientProvider<ElasticsearchClient>>();
+        A.CallTo(() => _clientProvider.ForCluster(A<string>._)).Returns(CreateInMemoryEsClient());

-        _handler = new MyHandler(_logger, _client, /* ... */);
+        _handler = new MyHandler(_logger, _clientProvider, /* ... */);
     }
```

Keep the existing in-memory-client helper (e.g. one built on a stubbed
`InMemoryRequestInvoker`/transport) — only the injection point changes. For ES7,
fake `IElasticsearchClientProvider<ElasticClient>` and return an in-memory NEST
client the same way.

If a `using Roblox.RobloxElasticsearchClient;` is needed for
`IElasticsearchClientProvider<TClient>`, add it. Build and run the unit tests
before moving to the deployment change.
