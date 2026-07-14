## Options / Config / CompletedConfig Pattern

- Every package in the consumer tree follows a three-stage configuration pattern: `Options` (user-facing flags) -> `Config` (intermediate, mutable) -> `CompletedConfig` (immutable, constructed only via `Config.Complete()`).
- `CompletedConfig` wraps an unexported `completedConfig` struct. This prevents external construction -- callers must go through `Complete()`.
- `NewOptions()` must set all defaults. `AddFlags()` registers pflag bindings with a dot-separated prefix (e.g. `consumer.auth.enabled`). `Validate()` returns `[]error`, not a single error.
- `Options.Complete()` returns `[]error` (not `(CompletedConfig, error)`). `Config.Complete()` returns `(CompletedConfig, []error)`. Follow the existing signature when adding new fields.
- When adding a new sub-package config (like auth or retry), embed its `*Options` in the parent `Options`, its `*Config` in the parent `Config`, and wire `NewConfig()` to call the sub-package's `NewConfig()`.
- `Config.KafkaConfig` can be injected directly (for testing) or built from Options during `Complete()`. If `c.KafkaConfig != nil`, it is used as-is; otherwise it is constructed from option fields.
- Auth settings are only added to the Kafka config map when `AuthConfig.Enabled` is true.

## Consumer Interface and Dependency Injection

- The `Consumer` interface abstracts `confluent-kafka-go`'s consumer. It contains only the methods actually used: `CommitOffsets`, `SubscribeTopics`, `Poll`, `IsClosed`, `Close`, `AssignmentLost`. Do not add methods to this interface unless the consumer loop needs them.
- `New()` accepts an optional `Consumer` parameter. When nil, a real Kafka consumer is created from config. When non-nil (tests), the provided mock is used. This is the primary injection point for testing.
- The `ClientProvider` interface (from `internal/client`) is similarly injected. Check `client.IsEnabled()` before making gRPC calls -- the client can be disabled, in which case message processing succeeds without API calls.

## Offset Management

- Auto-commit is disabled (`enable.auto.commit = false`). Offsets are committed manually via `CommitStoredOffsets()`.
- Offsets accumulate in `OffsetStorage` (a `[]kafka.TopicPartition` slice) and are batch-committed when the current offset satisfies the modulo condition: `int(offset) % CommitModulo == 0`.
- `CommitModulo` must be a positive non-zero integer (validated in `Options.Validate()`). Default is 10.
- `CommitStoredOffsets()` copies the slice, clears `OffsetStorage`, releases the mutex, then calls `CommitOffsets`. On failure, it re-acquires the mutex and restores or merges the offsets back. This copy-then-commit pattern prevents holding the lock during the blocking Kafka call.
- During operation-level retries (`Retry()`), stored offsets are committed before sleeping for backoff. This prevents offset starvation during long retry loops.

## Shutdown and Rebalance Coordination

- `offsetMutex` (sync.Mutex) protects `OffsetStorage` and `shutdownInProgress`. Every read or write to these fields must hold the lock.
- `Shutdown()` sets `shutdownInProgress = true` under the lock before committing remaining offsets and closing the consumer. This flag prevents the rebalance callback from double-committing.
- `RebalanceCallback()` checks `shutdownInProgress` under the lock. If true, it skips the offset commit and returns nil. If false and there are no stored offsets, it returns early. Otherwise it commits.
- The `RebalanceCallback` signature must satisfy `func(*kafka.Consumer, kafka.Event) error`. The method receives a `*kafka.Consumer` parameter but uses `i.Consumer` (the InventoryConsumer's embedded consumer) instead. Do not use the passed-in consumer parameter.
- `Shutdown()` always returns `ErrClosed`. The `Consume()` loop treats `ErrClosed` as a restartable condition; any other error from Shutdown is wrapped and propagated as fatal.

## Two-Level Retry Strategy

- **Consumer-level retry** (`Run()`): When `Consume()` returns `ErrClosed`, the entire consumer is recreated with a new Kafka connection and the loop restarts. This re-reads the current message from the earliest uncommitted offset. Controlled by `ConsumerMaxRetries` (default 2). Set to -1 for infinite retries.
- **Operation-level retry** (`Retry()`): Individual gRPC operations (ReportResource, DeleteResource) are retried with backoff within a single consume cycle. Controlled by `OperationMaxRetries` (default 3). Set to -1 for infinite retries.
- Backoff formula: `min(BackoffFactor * attempts * 300ms, MaxBackoffSeconds)`. Same formula at both levels.
- `Retry()` accepts optional variadic `errorHandler` functions. If the first handler returns true, the retry loop short-circuits and returns `(nil, nil)` -- the message is silently dropped. Used for NotFound errors on delete operations.
- When `Retry()` exhausts max retries, it returns `ErrMaxRetries`. This causes `ProcessMessage` to fail, which causes `Consume()` to exit the loop and trigger shutdown.

## Message Processing Pipeline

- Messages must have two Kafka headers: `operation` and `version`. Both are required and validated against allow-lists (`validOperations`, `validApiVersions`).
- Extra headers beyond the required set are silently ignored (filtered by `requiredHeaders` map during parsing).
- Header parsing uses `mapstructure` with `ErrorUnused: true` to decode into `EventHeaders`.
- Validation errors are wrapped with `ErrValidation` sentinel. Missing/invalid headers cause the consume loop to exit (`run = false`), triggering consumer-level restart.
- Message body follows the Debezium outbox pattern: `{"schema": {...}, "payload": {...}}`. The `MessagePayload.RequestPayload` field is an `interface{}` that gets re-marshaled to JSON then unmarshaled into the target protobuf type.
- `ParseCreateOrUpdateMessage` extracts `transaction_id` from `payload.representations.metadata.transaction_id` and sets it as the protobuf `IdempotencyKey` oneof. This only applies to `ReportResourceRequest`; other types are silently skipped.
- `ParseDeleteMessage` does not extract transaction_id.
- Operation dispatch in `ProcessMessage()` uses a switch on `headers.Operation`. Unknown operations log an error and are silently dropped (no error returned, no restart).
- The `migration` operation type uses transforms from `consumer/transforms/` to convert legacy host format. See the transforms package guidelines for the transform functions. Migration checks `IsHostDeleted()` first, then dispatches to either delete or report resource transforms.

## Kafka Consumer Configuration

- `client.id` is hardcoded to `"kic"` (the `clientID` constant). Consumer group ID defaults to `"kic"`.
- All Kafka timing settings are strings (milliseconds as string values), not integers. They are passed directly to `kafka.ConfigMap.SetKey()`.
- `auto.offset.reset` defaults to `"earliest"` -- new consumer groups start from the beginning of the topic.
- The `debug` setting is only added to the ConfigMap when non-empty.
- `statistics.interval.ms` defaults to `"60000"`. Stats events (`*kafka.Stats`) are unmarshaled and fed to the metrics collector.

## Metrics Integration

- Most error paths call `metricscollector.Incr()` with the appropriate counter and operation label. Errors during initial setup (before the metrics collector exists) cannot be counted.
- `Retry()` metrics labels require both `topic` and `suboperation` to be non-empty, or neither should be set. Setting only one adds noise.
- Stats events from Kafka are collected via `MetricsCollector.Collect()`. Unmarshal failures are logged and counted but do not stop the consumer.

## Testing Conventions

- Use the `TestCase` struct and its `TestSetup()` method to bootstrap tests. This creates Options, Config, CompletedConfig, a MockConsumer, and an InventoryConsumer in one call.
- Mock types live in `internal/mocks/mocks.go`: `MockConsumer` (implements the `Consumer` interface) and `MockClient` (implements `ClientProvider`). Both use testify/mock.
- Replace `tester.inv.Consumer` and `tester.inv.Client` with mocks after `TestSetup()` when you need custom mock behavior.
- Use `mock.Anything` for arguments you do not need to assert on. Use `.Maybe()` for methods that may or may not be called depending on race condition timing.
- Table-driven tests are the standard pattern. Use `t.Run(test.name, ...)` for subtests.
- Options tests use `common.AllOptionsHaveFlags()` to verify that every struct field with a `mapstructure` tag has a corresponding pflag registered. Pass sub-package field names (e.g., `"auth"`, `"retry-options"`) in the skip list since those are tested in their own packages.
- Race condition tests (`race_condition_test.go`) test concurrent shutdown + rebalance and concurrent offset storage access using goroutines and channels. Run tests with `-race` flag.
- Test message constants are defined at the top of `consumer_test.go` as package-level `const` values. Reuse these rather than creating new test fixtures when possible.
