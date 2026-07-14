# Kessel Inventory Consumer -- Claude Code Configuration

## Build and Test Commands

```shell
make build          # Compile to ./bin/inventory-consumer
make test           # Run all tests with -race and coverage
make lint           # Run golangci-lint v2.6.2 via container
make lint-fix       # Run golangci-lint with --fix
```

## Before Committing

1. Run `make test` -- tests include race detector and coverage
2. Run `make lint` -- catches style issues
3. No pre-commit hooks are configured in this repo

## CI Checks

GitHub Actions runs `build-test` and `golangci-lint` on every push/PR to main. Both must pass. Go version is read from `go.mod`. Tekton/Konflux pipelines build container images on PR and push.

@AGENTS.md
