FIPS_ENABLED?=true

GOHOSTOS:=$(shell go env GOHOSTOS)
GOPATH:=$(shell go env GOPATH)
GOOS?=$(shell go env GOOS)
GOARCH?=$(shell go env GOARCH)
GOBIN?=$(shell go env GOBIN)
GOFLAGS_MOD ?=

GOENV=GOOS=${GOOS} GOARCH=${GOARCH} CGO_ENABLED=1 GOFLAGS="${GOFLAGS_MOD}"
GOBUILDFLAGS=-gcflags="all=-trimpath=${GOPATH}" -asmflags="all=-trimpath=${GOPATH}"

ifeq (${FIPS_ENABLED}, true)
GOFLAGS_MOD+=-tags=fips_enabled
GOFLAGS_MOD:=$(strip ${GOFLAGS_MOD})
GOENV+=GOEXPERIMENT=strictfipsruntime,boringcrypto
GOENV:=$(strip ${GOENV})
endif

IMAGE ?="quay.io/cloudservices/kessel-inventory"
IMAGE_TAG=$(git rev-parse --short=7 HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)

ifeq ($(DOCKER),)
DOCKER:=$(shell command -v podman || command -v docker)
endif

ifeq ($(VERSION),)
VERSION:=$(shell git describe --tags --always)
endif

.PHONY: build
# build
build:
	$(warning Setting GOEXPERIMENT=strictfipsruntime,boringcrypto - this generally causes builds to fail unless building inside the provided Dockerfile. If building locally, run `make local-build`)
	mkdir -p bin/ && ${GOENV} GOOS=${GOOS} go build ${GOBUILDFLAGS} -ldflags "-X cmd.Version=$(VERSION)" -o ./bin/ ./...

.PHONY: local-build
local-build:
	mkdir -p bin/ && go build -ldflags "-X cmd.Version=$(VERSION)" -o ./bin/ ./...

.PHONY: test
test:
	@echo ""
	go test ./... -count=1 -race -short -covermode=atomic -coverprofile=coverage.txt
	@echo "Overall test coverage:"
	go tool cover -func=coverage.txt | grep total: | awk '{print $$3}'

.PHONY: lint
# run go linter with the repositories lint config
lint:
	@echo "Running golangci-lint"
	@$(DOCKER) run -t --rm -v $(PWD):/app:rw,z -w /app golangci/golangci-lint:v2.6.2 golangci-lint run -v

lint-fix:
	@echo "Running golangci-lint run --fix"
	@$(DOCKER) run -t --rm -v $(PWD):/app:rw,z -w /app golangci/golangci-lint:v2.6.2 golangci-lint run --fix -v

.PHONY: docker-build-push
docker-build-push:
	./build_deploy.sh

.PHONY: build-push-minimal
build-push-minimal:
	./build_push_minimal.sh

.PHONY: inventory-consumer-up
inventory-consumer-up:
	./scripts/start-inventory-consumer.sh full-setup

.PHONY: inventory-consumer-down
inventory-consumer-down:
	./scripts/stop-inventory-consumer.sh

.PHONY: setup-hbi-db
setup-hbi-db:
	PGPASSWORD=supersecurewow psql -h localhost -p 5435 -U postgres -d host-inventory -f development/configs/hosts.schema.sql

.PHONY: setup-connectors
setup-connectors: setup-migration-connector setup-outbox-connector

.PHONY: setup-migration-connector
setup-migration-connector:
	curl -d @development/configs/debezium-migration-connector.json -H 'Content-Type: application/json' -X POST http://localhost:8084/connectors

.PHONY: setup-outbox-connector
setup-outbox-connector:
	curl -d @development/configs/debezium-outbox-connector.json -H 'Content-Type: application/json' -X POST http://localhost:8084/connectors

.PHONY: check-connector-status
check-connector-status:
	curl localhost:8084/connectors/hbi-outbox-connector/status | jq -r
	curl localhost:8084/connectors/hbi-migration-connector/status | jq -r

.PHONY: delete-connectors
delete-connectors: delete-migration-connector delete-outbox-connector

.PHONY: delete-migration-connector
delete-migration-connector:
	curl -X DELETE http://localhost:8084/connectors/hbi-migration-connector

.PHONY: delete-outbox-connector
delete-outbox-connector:
	curl -X DELETE http://localhost:8084/connectors/hbi-outbox-connector

.PHONY: delete-connectors
delete-connectors: delete-migration-connector delete-outbox-connector

.PHONY: remove-replication-slots
remove-replication-slots:
	-PGPASSWORD=supersecurewow psql -h localhost -p 5435 -U postgres -d host-inventory -c "SELECT pg_drop_replication_slot('debezium_hosts')" -c "SELECT pg_drop_replication_slot('debezium_outbox')"

.PHONY: setup-migration-test
setup-migration-test: inventory-consumer-up

.PHONY: run-migration-test
run-migration-test:
	./scripts/run-migration-test.sh

.PHONY: cleanup-migration-test
cleanup-migration-test:
	./scripts/cleanup-migration-test.sh
