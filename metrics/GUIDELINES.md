## Metric Prefixes

Two prefixes exist. Use the correct one based on the metric's origin:

- `consumer_stats_` -- for metrics sourced from Kafka `Stats` callback messages (the `StatsData` struct). These are scraped from librdkafka's internal statistics.
- `consumer_` -- for application-level counters that the consumer code increments directly (message processing, errors, etc.).

Never invent a third prefix. All metric names in this package must start with one of these two constants (`statsPrefix`, `prefix`).

## Naming Conventions

- Use `snake_case` for all metric names after the prefix (e.g., `consumer_lag_stored`, not `consumerLagStored`).
- Match the librdkafka stats JSON field name whenever the metric maps 1:1 to a stats field (e.g., `fetchq_cnt`, `rebalance_age`, `lo_offset`).
- Do not add a unit suffix; Prometheus's `_total` suffix is appended automatically to counters by the OTel-Prometheus exporter.

## MetricsCollector Struct

`MetricsCollector` holds all OTel instruments. Rules:

1. Every field must be either `metric.Int64Gauge` or `metric.Int64Counter`. No floats, no histograms.
2. Stats-sourced fields (Kafka stats callback) are unexported (lowercase). App-level counters that are incremented from `consumer/` are exported (uppercase): `MsgsProcessed`, `MsgProcessFailures`, `ConsumerErrors`, `KafkaErrorEvents`.
3. `subscribedTopics` stores the topic list passed at init time and is used in `Collect()` to iterate only over relevant topics.

## Initialization Pattern

Initialization is a method on `*MetricsCollector`, not a constructor returning a new value:

```go
var mc metricscollector.MetricsCollector
err := mc.New(config.Topics)
```

Inside `New`:
1. `NewMeterProvider()` creates a Prometheus exporter-backed `sdkmetric.MeterProvider` with service name `kessel-inventory-consumer`.
2. `NewMeter(provider)` creates a meter scoped to `kessel-inventory-consumer`.
3. Each field is registered on the meter. If registration fails, return immediately.
4. Topics are stored in `m.subscribedTopics`.

When adding a new metric, add the field to the struct AND register it in `New`. The existing test (`TestMetrics_New`) uses reflection to verify every field is non-zero after initialization -- a field added without registration will fail the test.

## Choosing Gauge vs Counter

- Use `Int64Gauge` for point-in-time values from Kafka stats: offsets, lag, queue sizes, state indicators, ages. Record with `.Record(ctx, value, labels)`.
- Use `Int64Counter` for monotonically increasing values: messages processed, errors, rebalance count. Update with `.Add(ctx, value, labels)`. For stats-sourced counters, pass the absolute value from librdkafka (Prometheus computes deltas). For app-level counters, increment by 1 via the `Incr` helper.
- Boolean-style state indicators (e.g., `fetchState`, `state`) are gauges recording `0` for the healthy state and `1` for any unhealthy state, with the actual state string as an attribute. For example, when `CGRP.State == "up"`, `consumer_stats_state` records `0` with attribute `state="up"`. The Grafana dashboard filters on the `state="up"` attribute to identify the consumer group -- the gauge value `0` indicates healthy.

## The Incr Helper

`Incr` is a package-level function for incrementing exported app-level counters by 1. It is the only way counters should be incremented from outside the package.

```go
metricscollector.Incr(i.MetricsCollector.MsgProcessFailures, "ParseHeaders", fmt.Errorf("missing headers"),
    metricscollector.AddExtraLabel("topic", *e.TopicPartition.Topic))
```

Parameters:
- `counter` -- one of the four exported `Int64Counter` fields on `MetricsCollector`.
- `operation` -- a string identifying what was being attempted. Use the function or operation name (e.g., `"ParseHeaders"`, `"ReportResource"`, `"Retry"`).
- `errReason` -- the error that caused the failure, or `nil`. When non-nil it is added as attribute `reason`.
- `extraAttrs` -- optional additional `attribute.KeyValue` values. Build these with `AddExtraLabel(key, value)`.

Rules for callers:
- Always pass a descriptive `operation` string -- never empty.
- Pass `errReason` only when the error message adds diagnostic value; pass `nil` for known/expected failure modes where the operation name alone is sufficient.
- When a metric needs to be traceable to a specific topic, pass both `topic` and any relevant sub-label (e.g., `suboperation`). Pass either both or neither.

## AddExtraLabel

Use `metricscollector.AddExtraLabel(key, value)` to build extra attributes for `Incr`. Do not construct `attribute.KeyValue` manually unless you are in the `kafka.Error` handler (where `attribute.String` is used directly for `code` and `error` attributes).

## Attribute Conventions

Stats-sourced metrics (via `LabelSet`):
- `name` -- Kafka client name (always present)
- `client_id` -- Kafka client ID (always present)
- `topic` -- topic name (present for partition-level metrics, empty string for top-level/cgrp)
- `partition` -- partition key string (present for partition-level metrics, empty string for top-level/cgrp)
- Additional state attributes: `fetch_state`, `state`, `last_rebalance_reason` are added inline where applicable.

App-level counters (via `Incr`):
- `operation` -- always present, identifies the operation or function.
- `reason` -- present only when `errReason != nil`.
- `topic` -- added via `AddExtraLabel` when the failure is traceable to a topic.
- `suboperation` -- added via `AddExtraLabel` in retry paths to distinguish the underlying call.
- `code`, `error` -- used on `KafkaErrorEvents` for Kafka error events.

## Collect Method

`Collect(stats StatsData)` is called on every `kafka.Stats` event. It:
1. Records top-level metrics with `LabelSet("", "")` (no topic/partition).
2. Iterates `m.subscribedTopics`, then each partition within each topic. Partitions with key `"-1"` (aggregate) are skipped.
3. Records CGRP metrics with `LabelSet("", "")` plus inline state attributes.

When adding a new stats-based metric, follow this flow: add field to `StatsData`/sub-struct, add gauge/counter to `MetricsCollector`, register in `New`, record in `Collect` at the appropriate nesting level.

## Prometheus HTTP Server

`ServeMetrics()` serves the Prometheus `/metrics` endpoint on port `9000`. It is launched as a goroutine from `cmd/start.go`. It uses the default `http.ServeMux`. Do not register other handlers on the default mux. The port is hardcoded; if it needs to become configurable, it should move to the options/config pattern used by the consumer.

## Kafka Stats Callback Integration

The consumer enables librdkafka stats by setting `statistics.interval.ms` in the Kafka config. Stats arrive as `*kafka.Stats` events in the poll loop. The consumer unmarshals the JSON into `StatsData` and calls `Collect()`. If unmarshalling fails, it increments `MsgProcessFailures` with operation `"StatsCollection"` and continues (does not break the loop).

## Grafana Dashboard Alignment

The dashboard in `dashboards/grafana-dashboard-kessel-inventory-consumer.configmap.yaml` queries these exact Prometheus metric names (with `_total` suffix auto-appended to counters):

| Dashboard panel | Metric queried |
|---|---|
| Active Consumers | `consumer_stats_state{state="up"}` |
| Msgs in Queue | `consumer_stats_replyq` |
| Last Rebalance | `consumer_stats_rebalance_age` |
| Rebalance Events | `consumer_stats_rebalance_cnt_total` |
| Consumer Processing Rate | `consumer_msgs_processed_total` |
| Consumer Processing Failure Rate | `consumer_msg_process_failures_total / consumer_msgs_processed_total` |
| Consumer Error Rate | `consumer_errors_total / consumer_msgs_processed_total` |
| Kafka Error Events | `consumer_kafka_error_events_total` |
| HBI Processed Events | `consumer_msgs_processed_total{topic="outbox.event.hbi.hosts"}` |

When adding or renaming a metric, update the dashboard ConfigMap to match. When adding a `topic` label to a counter, verify per-topic panels still aggregate correctly.

## Testing

The test in `metricscollector_test.go` uses reflection to verify that every field on `MetricsCollector` is non-zero after `New()`. This means:

1. Any new field added to `MetricsCollector` will automatically be caught if not initialized.
2. Tests cover both single-topic and multi-topic initialization.
3. The test validates field count parity between the type definition and the instantiated struct.

When adding new metrics, the existing test will fail if the field is not registered in `New` -- no additional test case is needed for initialization.
