## Architecture

The `internal/client/` package wraps the Kessel Inventory gRPC API using the `kessel-sdk-go` SDK. It follows the Options -> Config -> CompletedConfig lifecycle pattern used throughout this project. The consumer loop interacts with the inventory API exclusively through the `ClientProvider` interface.

## ClientProvider Interface

`ClientProvider` is the sole contract between the consumer loop and the inventory API. All consumer code must depend on `ClientProvider`, never on `KesselClient` directly.

The interface has three methods:
- `ReportResource(*v1beta2.ReportResourceRequest) (*v1beta2.ReportResourceResponse, error)` -- create or update a resource
- `DeleteResource(*v1beta2.DeleteResourceRequest) (*v1beta2.DeleteResourceResponse, error)` -- delete a resource
- `IsEnabled() bool` -- gate all API calls; callers must check this before invoking ReportResource/DeleteResource

When adding a new inventory API operation:
1. Add the method to `ClientProvider` in `client.go`
2. Implement it on `KesselClient` (delegate to the embedded `v1beta2.KesselInventoryServiceClient`)
3. Add the method to `MockClient` in `internal/mocks/mocks.go`
4. Add the corresponding operation constant and message processing case in `consumer/consumer.go`

Every `ClientProvider` method that wraps a gRPC call must pass `context.Background()` to the underlying SDK stub and wrap errors with `fmt.Errorf("failed to <action>: %w", err)`.

## Options / Config / CompletedConfig Lifecycle

This pattern is shared across the codebase. For the client package:

1. `NewOptions()` returns defaults (Enabled=true, Insecure=false, EnableOidcAuth=false)
2. `Options.AddFlags(fs, prefix)` registers CLI flags with dot-delimited prefix (e.g., `client.url`)
3. `Options.Complete()` runs completion logic (currently a no-op but must be called) and returns `[]error`
4. `Options.Validate()` enforces constraints and returns `[]error`
5. `NewConfig(options).Complete()` returns `(CompletedConfig, []error)`, producing a `CompletedConfig` passed to `New()`

The caller in `cmd/start.go` must call Complete then Validate on Options before constructing the Config. The `CompletedConfig` struct uses a private inner `completedConfig` to prevent construction outside the Complete method.

Every field in `Options` must have a corresponding flag registered in `AddFlags`. The test `TestOptions_AddFlags` uses `common.AllOptionsHaveFlags` to enforce this -- adding an Options field without a flag will fail the test.

## Authentication Modes

Three mutually exclusive modes exist, resolved in `New()`:

| Mode | Flags | SDK Builder Call | Transport |
|------|-------|-----------------|-----------|
| Insecure | `Insecure=true, EnableOidcAuth=false` | `.Insecure().Build()` | No TLS |
| TLS only | `Insecure=false, EnableOidcAuth=false` | `.Unauthenticated(channelCreds).Build()` | TLS with CA cert |
| OIDC | `EnableOidcAuth=true, Insecure=false` | `.Authenticated(callCreds, channelCreds).Build()` | TLS + OAuth2 |

Validation rule: `EnableOidcAuth=true` and `Insecure=true` cannot both be set. This is enforced in `Options.Validate()`.

When `Enabled=false`, `New()` returns a `KesselClient` with a nil `KesselInventoryServiceClient` and `Enabled=false`. No connection is established.

## kessel-sdk-go Usage

The SDK dependency is `github.com/project-kessel/kessel-sdk-go`. Key imports:
- `kessel/inventory/v1beta2` -- service client interface, request/response types, `NewClientBuilder`
- `kessel/grpc` (aliased `kesselgrpc`) -- `OAuth2CallCredentials` for OIDC
- `kessel/auth` -- `NewOAuth2ClientCredentials` for OAuth2 client credentials
- `kessel/inventory/v1` -- health service client (used only in readyz, not in this package)

Client construction always goes through `v1beta2.NewClientBuilder(url)` followed by one of the three auth mode builder chains. The builder returns `(client, conn, error)` -- the `conn` (`*grpc.ClientConn`) is currently discarded (noted as a TODO for connection lifecycle management).

Do not construct gRPC connections manually for inventory API calls. Always use `NewClientBuilder`. The readyz command is the only place that constructs a raw `grpc.NewClient` connection, because it uses a different service (`v1.KesselInventoryHealthServiceClient`).

## TLS Certificate Handling

`configureTLS(caPath)` reads a CA cert file from disk and delegates to `configureTLSFromData(caCert)`. The split exists specifically so tests can use in-memory certificates via `configureTLSFromData` without touching the filesystem.

When writing tests that need TLS credentials, use `createTestCACertData(t)` to generate a self-signed CA cert in memory, then call the `newWithCACertData` test helper or `configureTLSFromData` directly. Do not create temp cert files in tests.

## Consumer Integration

The consumer holds `ClientProvider` as the `Client` field on `InventoryConsumer`. The flow:
1. `cmd/start.go` constructs `KesselClient` via `kessel.New(completedConfig, logger)`
2. Passes it as `ClientProvider` to `consumer.Run(options, config, client, logger)`
3. `Run()` internally constructs `InventoryConsumer` via `consumer.New(config, client, logger, nil)`
4. In `ProcessMessage`, every API call is guarded by `i.Client.IsEnabled()` before invocation
4. API calls are wrapped in `i.Retry(func() (interface{}, error) { ... })` for retry with backoff
5. gRPC status codes are inspected via `status.FromError(err)` for specific error handling (e.g., `codes.NotFound` for delete operations causes message drop instead of retry)

When adding new operations, follow the existing pattern: check `IsEnabled()`, wrap in `Retry()`, and handle domain-specific gRPC status codes with an `errorHandler` function.

## Error Handling

- All gRPC errors from `ClientProvider` methods are wrapped with `fmt.Errorf` context
- The consumer's `Retry` mechanism handles transient failures with exponential backoff
- For `DeleteResource`, `codes.NotFound` is treated as a non-error (message is dropped) via custom error handlers passed to `Retry`
- When `Retry` exhausts max attempts, it returns `ErrMaxRetries`, which causes the consumer loop to restart

## Testing

Mock the `ClientProvider` interface using `mocks.MockClient` in `internal/mocks/mocks.go`. This mock uses `testify/mock` and implements all three interface methods.

Pattern for testing consumer code that calls the client:
```go
mockClient := &mocks.MockClient{}
mockClient.On("ReportResource", mock.Anything).Return(&v1beta2.ReportResourceResponse{}, nil)
var client kessel.ClientProvider = mockClient
```

Pattern for testing client construction with TLS:
```go
caCertData := createTestCACertData(t)
client, err := newWithCACertData(config, logger, caCertData)
```

When testing the `New()` constructor for disabled clients, verify that `KesselInventoryServiceClient` is nil and `Enabled` is false. For enabled clients, verify both fields are non-nil/true.

## Health Check (readyz)

The `readyz` command in `cmd/readyz.go` shares `kessel.Options` for URL and TLS configuration but does NOT use `ClientProvider` or `KesselClient`. It builds its own raw gRPC connection to call `v1.KesselInventoryHealthServiceClient.GetLivez`. This is intentional -- the health check uses a different API version (`v1` vs `v1beta2`) and a different service.

The readyz TLS logic is simpler: if `CACertFile` is set, use TLS; otherwise use insecure. It does not support OIDC.

## Key Invariants

- `ClientProvider.IsEnabled()` must always be checked before calling `ReportResource` or `DeleteResource`
- `EnableOidcAuth` and `Insecure` must never both be true (enforced by validation)
- `InventoryURL` must be non-empty when `Enabled` is true (enforced by validation)
- The `grpc.ClientConn` returned by the SDK builder is not managed; do not add connection pooling or lifecycle management without addressing the TODO in `New()`
- The `readyz` command reuses `Options` for flag parsing but operates independently of `ClientProvider`
