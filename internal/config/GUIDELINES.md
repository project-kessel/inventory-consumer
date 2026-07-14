## Options / Config / CompletedConfig Pattern

Each configurable component uses a three-tier pattern spread across two files (or one file for simpler sub-packages):

**`options.go`** defines:
- `Options` struct -- user-facing settings with `mapstructure` tags. Holds only primitive/sub-Options fields.
- `NewOptions()` -- returns `*Options` with sensible defaults hardcoded (not from config file).
- `AddFlags(fs *pflag.FlagSet, prefix string)` -- registers every Options field as a CLI flag. Sub-options call their own `AddFlags` with an extended prefix.
- `Validate() []error` (optional) -- returns a slice of errors for invalid combinations. Guard conditional checks on `Enabled` where applicable. Not all Options structs require this method (e.g., auth and retry sub-packages omit it).
- `Complete() []error` (optional) -- post-processing hook for deriving values; return nil if nothing to derive. Not all Options structs require this method.

**`config.go`** defines:
- `Config` struct -- embeds `*Options` or holds it as a field, adds runtime objects (e.g., `*kafka.ConfigMap`).
- `NewConfig(o *Options) *Config` -- wraps Options and builds sub-Configs from sub-Options.
- `completedConfig` (unexported) -- the sealed, fully-resolved configuration. May embed `*Options` or hold it as a field.
- `CompletedConfig` (exported) -- wraps `*completedConfig`. This is the only type consumers should accept, enforcing that `Complete()` was called.
- `Complete()` -- transforms Config into CompletedConfig. Build derived runtime objects here (e.g., Kafka ConfigMap). Signature varies by package: top-level packages return `(CompletedConfig, []error)`, while some sub-packages (auth, retry) return just `CompletedConfig`. Return errors rather than panicking when the signature includes error return.

### Lifecycle in Command Handlers

The required call sequence in a command's `RunE` is:
```
options.Complete() -> options.Validate() -> NewConfig(options).Complete()
```
Always check each step's error return before proceeding (when the method returns errors). See `cmd/start.go` for the canonical example.

### Adding a New Configurable Component

1. Create `options.go` with `Options`, `NewOptions()`, `AddFlags()`, and optionally `Validate()` and `Complete()`.
2. Create `config.go` with `Config`, `NewConfig()`, `completedConfig`, `CompletedConfig`, and `Complete()`.
3. Add a `*yourpkg.Options` field to `internal/config/OptionsConfig` and initialize it in `NewOptionsConfig()`.
4. Wire `AddFlags()` into the relevant command constructor (e.g., `startCommand`) using the appropriate prefix.
5. Call `viper.BindPFlags(cmd.Flags())` in `cmd/root.go` `init()` after adding the command.
6. Add the corresponding YAML section to `.inventory-consumer.yaml`.
7. Write an `AllOptionsHaveFlags` test (see below).

## mapstructure Tag Conventions

- Every exported field on an Options struct must have a `mapstructure:"<key>"` tag.
- Use lowercase kebab-case for tag values: `mapstructure:"bootstrap-servers"`, `mapstructure:"consumer-group-id"`.
- The tag value must exactly match the flag name suffix registered in `AddFlags()` and the YAML key in the config file.
- Sub-Options pointer fields use a tag matching the prefix passed to their `AddFlags()`: e.g., `*auth.Options` tagged `mapstructure:"auth"` corresponds to `AddFlags(fs, prefix+"auth")`.

## Viper Binding and Flag Registration

### AddFlags Prefix Protocol

`AddFlags` receives a `prefix string`. If non-empty, prepend `prefix + "."` to every flag name. This creates the dot-separated hierarchy that Viper uses to map between YAML keys, flags, and env vars.

```
consumer.auth.sasl-mechanism   <-- flag name
consumer:                      <-- YAML nesting
  auth:
    sasl-mechanism: ...
```

### Flag Binding in cmd/root.go

Flags are registered on the *subcommand*, not the root. After `rootCmd.AddCommand(startCmd)`, call `viper.BindPFlags(startCmd.Flags())`. Root-level persistent flags (like `--config`) are bound separately on `rootCmd.PersistentFlags()`.

### Environment Variable Limitation

Viper's `AutomaticEnv()` replaces dots with underscores for env var lookup, but it does NOT replace hyphens. A flag named `consumer.bootstrap-servers` maps to env var `INVENTORY_CONSUMER_CONSUMER.BOOTSTRAP-SERVERS` -- which is not a valid shell variable name. Env var overrides only work reliably for keys that contain no hyphens. Do not promise env-var-based configuration for hyphenated keys without adding explicit `viper.BindEnv()` calls.

The env prefix is set to the application name: `viper.SetEnvPrefix("inventory-consumer")`. Note that Viper does not replace hyphens in the prefix itself, so the resulting env var prefix is `INVENTORY-CONSUMER_` (with a hyphen), not `INVENTORY_CONSUMER_`. No `SetEnvKeyReplacer` is configured.

## Config File Format and Search Paths

- Format: YAML, file named `.inventory-consumer.yaml`.
- Search order: (1) explicit `--config` flag, (2) `INVENTORY_CONSUMER_CONFIG` env var (resolved to absolute path), (3) current working directory, (4) user home directory.
- Top-level YAML keys correspond to OptionsConfig field tags: `consumer`, `client`, `log`.
- Nesting follows the mapstructure tags:
  ```yaml
  consumer:
    auth:
      enabled: false
    retry-options:
      consumer-max-retries: 3
  client:
    url: "localhost:9000"
  ```
- Viper unmarshals the entire file into `*OptionsConfig` via `viper.Unmarshal(&options)`.

## OptionsConfig (internal/config)

`OptionsConfig` is the top-level aggregation struct. It holds one `*Options` pointer per component:

```go
type OptionsConfig struct {
    Consumer *consumer.Options
    Client   *kessel.Options
}
```

When adding a component, add a field here and initialize it in `NewOptionsConfig()`. The field name is not tagged -- Viper matches by the mapstructure tags on the nested struct.

`LogConfigurationInfo()` is a standalone function (not a method) that logs non-secret config values at debug level. Update it when adding new components.

## ClowdApp Config Injection

- Runs in `cmd/root.go` `init()`, gated by `clowder.IsClowderEnabled()`.
- Calls `options.InjectClowdAppConfig(clowder.LoadedConfig)` which mutates the already-constructed `OptionsConfig` in place.
- `InjectClowdAppConfig` dispatches to per-component methods (e.g., `ConfigureConsumer`). Guard each with a nil check on the relevant AppConfig section.
- Kafka SASL mapping from ClowdApp fields:
  - `Brokers[0].SecurityProtocol` -> `AuthOptions.SecurityProtocol`
  - `Brokers[0].Sasl.SaslMechanism` -> `AuthOptions.SASLMechanism`
  - `Brokers[0].Sasl.Username` -> `AuthOptions.SASLUsername`
  - `Brokers[0].Sasl.Password` -> `AuthOptions.SASLPassword`
- Bootstrap servers are assembled from ALL brokers (`Hostname:Port`), not just the first.
- SASL config is read only from `Brokers[0]`. Check `SecurityProtocol != nil` before accessing `Sasl`.

## AllOptionsHaveFlags Test Helper

`common.AllOptionsHaveFlags(t, prefix, fs, options, skippedFlags)` uses reflection to verify that every field in an Options struct (identified by its `mapstructure` tag) has a corresponding registered flag in the FlagSet.

- Call it in every Options package's `TestOptions_AddFlags`.
- Pass the same prefix used in `AddFlags`.
- Pass `skippedFlags` for fields that are sub-Options pointers (they register their own flags via their own `AddFlags`). Example: `consumer.Options` skips `"auth"` and `"retry-options"`.
- This test catches: (a) new fields added to Options without a corresponding flag, (b) mismatches between mapstructure tags and flag names.

## Validation Rules

- `Validate()` returns `[]error`, not a single error. Collect all validation failures rather than short-circuiting.
- Place validation in `Options.Validate()` when the Options struct needs it, not in `Config.Complete()`. Complete handles construction; Validate handles correctness.
- Not all Options structs require a `Validate()` method -- only those with validation rules (e.g., consumer, client).
- Gate required-field checks on the component's `Enabled` flag when present (e.g., `BootstrapServers` is only required when `Enabled == true`).
- Cross-field mutual exclusion belongs in Validate (e.g., `EnableOidcAuth && Insecure` is invalid in the client package).
