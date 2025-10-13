# Local HBI Outbox Consumer Processing Using Kafka Event

This process is useful for testing the Kessel service individually and does not require any extra HBI bits. This process works by publishing a message to the HBI outbox topic which will then be captured by the Inventory Consumer and replicated down to relations.

To publish the messages, you will need the `kcat` cli (See [Install instructions](https://github.com/edenhill/kcat?tab=readme-ov-file#install))

### Steps:

1. Spin up everything via podman compose (See [Using Podman Compose](../../README.md#using-podman-compose-recommended))

2. Publish messages using `kcat`

```shell
# Create an HBI Host using Outbox
echo '{"schema":{"type":"string","optional":false},"payload":"dd1b73b9-3e33-4264-968c-e3ce55b9afec"}|{"schema":{"type":"struct","fields":[{"type":"string","optional":true,"field":"type"},{"type":"string","optional":true,"field":"reporter_type"},{"type":"string","optional":true,"field":"reporter_instance_id"},{"type":"struct","fields":[{"type":"struct","fields":[{"type":"string","optional":true,"field":"local_resource_id"},{"type":"string","optional":true,"field":"api_href"},{"type":"string","optional":true,"field":"console_href"},{"type":"string","optional":true,"field":"reporter_version"}],"optional":true,"name":"metadata"},{"type":"struct","fields":[{"type":"string","optional":true,"field":"workspace_id"}],"optional":true,"name":"common"},{"type":"struct","fields":[{"type":"string","optional":true,"field":"satellite_id"},{"type":"string","optional":true,"field":"subscription_manager_id"},{"type":"string","optional":true,"field":"insights_id"},{"type":"string","optional":true,"field":"ansible_host"}],"optional":true,"name":"reporter"}],"optional":true,"name":"representations"}],"optional":true,"name":"payload"},"payload":{"type":"host","reporter_type":"hbi","reporter_instance_id":"redhat","representations":{"metadata":{"local_resource_id":"dd1b73b9-3e33-4264-968c-e3ce55b9afec","api_href":"https://apiHref.com/","console_href":"https://www.console.com/","reporter_version":"2.7.16"},"common":{"workspace_id":"a64d17d0-aec3-410a-acd0-e0b85b22c076"},"reporter":{"satellite_id":"2c4196f1-0371-4f4c-8913-e113cfaa6e67","subscription_manager_id":"af94f92b-0b65-4cac-b449-6b77e665a08f","insights_id":"05707922-7b0a-4fe6-982d-6adbc7695b8f","ansible_host":"host-1"}}}}' | kcat -P -b localhost:9092 -H "operation=ReportResource" -H "version=v1beta2" -t outbox.event.hbi.hosts -K "|"

# Delete the same HBI Host using Outbox
echo '{"schema":{"type":"string","optional":false},"payload":"dd1b73b9-3e33-4264-968c-e3ce55b9afec"}|{"schema":{"type":"struct","fields":[{"type":"struct","fields":[{"type":"string","optional":true,"field":"resource_type"},{"type":"string","optional":true,"field":"resource_id"},{"type":"struct","fields":[{"type":"string","optional":true,"field":"type"}],"optional":true,"name":"reporter"}],"optional":true,"name":"reference"}],"optional":true,"name":"payload"},"payload":{"reference":{"resource_type":"host","resource_id":"dd1b73b9-3e33-4264-968c-e3ce55b9afec","reporter":{"type":"hbi"}}}}' | kcat -P -b localhost:9092 -H "operation=DeleteResource" -H "version=v1beta2" -t outbox.event.hbi.hosts -K "|"
```

Once sent, you can review the logs or any databases and see the replication throughout

```shell
# check Inventory Consumer logs
podman logs development-inventory-consumer-1

# check Inventory API logs for resource creation and internal consumer replication
podman logs development-inventory-api-1

# check Relations API logs for tuple creation events
podman logs relations-api-relations-api-1

# access resources in Inventory API DB
psql -h localhost -p 5433 -d spicedb -U postgres # requires password available in Inventory API repo
```

# HBI Migration Testing using Hosts Table and Debezium

To test HBI Migration (or outbox processing) using Debezium, it is recommend to leverage the ephemeral process using the insights-service-deployer script. This will ensure the latest HBI code changes and database schema changes as to avoid false negatives/positives in testing. See the [HBI Migration runbook](https://github.com/project-kessel/insights-service-deployer/blob/main/docs/hbi-migration-runbook.md) for the process

### Ad-Hoc Snapshots

If you're testing HBI with Debezium using the above ephemeral process, you can also test performing blocking and incremental snapshots through Debeizum.

To trigger the snapshot:

1. Spin up the Kessel Debug container

```shell
oc process --local \
    -f https://raw.githubusercontent.com/project-kessel/inventory-api/refs/heads/main/tools/kessel-debug-container/kessel-debug-deploy.yaml \
    -p ENV="env-$(oc project)" | oc apply -f -

# rsh to the debug container
oc rsh kessel-debug

# Setup Kafka env vars
source /usr/local/bin/env-setup.sh
```

2. Trigger the snapshot by producing an event to the snapshot table

```bash
# For a blocking snapshot
echo 'host-inventory|{"type":"execute-snapshot","data":{"data-collections":["hbi.hosts"],"type":"blocking"}}' | kcat -P -b $BOOTSTRAP_SERVERS -t host-inventory.signal -K "|"

# For an incremental snapshot
echo 'host-inventory|{"type":"execute-snapshot","data":{"data-collections":["hbi.hosts"],"type":"INCREMENTAL"}}' | kcat -P -b $BOOTSTRAP_SERVERS -t host-inventory.signal -K "|"
```
