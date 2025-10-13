# Consumer Message Processing Failures

## Prerequisites

Remediations covered in this guide will require the following:
1. Access to running Inventory API pod logs
2. Access to a running container with Kafka CLI tools (covered in runbooks where needed)
3. Kafka connection information including bootstrap servers and authentication credentials (covered in runbooks where needed)


## Schema/API Validation Related Issues

When a message is processed by the Inventory Consumer, it leverages the Inventory API client to create/delete the resource via API quest. Validation of requests for Inventory API occur at two levels:
1. Schema validation: Does the request data contain all the required data as outlined by the resource types [schema definition](https://github.com/project-kessel/inventory-api/tree/main/data/schema/resources)?
2. API Validation: Does the request data contain all the required data by the API to facilitate the request?

### Inventory Consumer fails to Create/Modify a Resource due to Schema Validation Errors

**Example Error in Inventory Consumer Logs**

```
msg=Error processing request (max attempts reached: 4): failed to report resource: rpc error: code = InvalidArgument desc = missing 'common' field in payload - schema for 'host' has required fields
```

**Reason**

The Inventory API request made by the Inventory Consumer using the API client has failed schema validation for the particular resource. The request is crafted directly from the payload contents of a Kafka message produced by Debezium from the service providers source database's outbox table. If data is missing from the outbox write that is required for the specific resources schema, the request will fail.

**Verify and Remediate**

You can verify if there is a schema mismatch one of two ways:

1. Check the loaded schema in Inventory API for the specific resource

2. Compare the loaded schema to the expected schema

The schema is deployed via App Interface and is visible in the [`resources-tarball`](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/resources/insights-stage/kessel-stage/kessel-inventory-schema-configmap.yml?ref_type=heads). You can dump the ConfigMap contents to a tar file and unpack, or for simplicity sakes, you can exec/rsh to an Inventory API pod and review the contents in the container under `/data/schema/resources/`.

Compare the schema validation error to the schema in container:
* If the error matches a validation rule, then the Inventory API pods have the current schema loaded and are properly denying the request.
* If the error does not match a valid rule in the schema, its possible the Inventory API pod has not loaded the current ConfigMap and recycling the pods will trigger them to load the new schema

If the error matches a validation rule but the validation is not expected in the latest schema, compare the schema validation error to the [schema definitions](https://github.com/project-kessel/inventory-api/tree/main/data/schema/resources) in Github. If the schemas do not match, its possible the `resources-tarball` ConfigMap has not been updated with a current version of the tar file and needs to be updated. Once updated, this would resume message processing.

If the request is being denied for a valid reason, the consumer will not continue processing further messages by design. The message will need to be skipped to continue processing. To capture the event data and skip the message, see [Skipping Offsets to Restore Processing](#skipping-offsets-to-restore-processing)

### Inventory Consumer fails to Create/Modify a Resource due to API Validation Failures

**Example Error in Inventory Consumer Logs**

```bash
msg=request failed: failed to report resource: rpc error: code = InvalidArgument desc = validation error:
- reporter_type: value length must be at least 1 characters [string.min_len]
- reporter_type: value does not match regex pattern `^[A-Za-z0-9_-]+$` [string.pattern]
- reporter_instance_id: value length must be at least 1 characters [string.min_len]
- representations.metadata.local_resource_id: value length must be at least 1 characters [string.min_len]
- representations.metadata.api_href: value length must be at least 1 characters [string.min_len]
```

**Reason**

The Inventory API request made by the Inventory Consumer using the API client has failed API validation. The request is crafted directly from the payload contents of a Kafka message produced by Debezium from the service providers source database's outbox table. If data is missing from the outbox write that is required for the specific API request body, the request will fail.

**Verify and Remediate**

Inventory API validation is built into the protobuf files used to generate the API. Any requirements for a request can be found in the [Buf Schema Registry](https://buf.build/project-kessel/inventory-api/docs/main:kessel.inventory.v1beta2).

For the Kessel Inventory Consumer, we are concerned with our two Resource request types:

[ReportResourceRequest](https://buf.build/project-kessel/inventory-api/docs/main:kessel.inventory.v1beta2#kessel.inventory.v1beta2.ReportResourceRequest)

[DeleteResourceRequest](https://buf.build/project-kessel/inventory-api/docs/main:kessel.inventory.v1beta2#kessel.inventory.v1beta2.DeleteResourceRequest)

The supported resource types can be found in the [schemas folder](https://github.com/project-kessel/inventory-api/tree/main/data/schema/resources)

Review the validation requirements for the request fields (as denoted by `buf.validate.field` in the request fields). If the validation errors in the pod logs match the validation requirements, then the payload does not meet the API requirements and cannot be processed. The service provider would need to be notified to address the data write issue to their outbox. To ensure data consistency, the Inventory Consumer will not continue to the next message unless all messages are processed. This effectively prevents any future events being processed. To remediate, the current message failing to process must be skipped by updating the current offset. See [Skipping Offset to Restore Processing](#skipping-offsets-to-restore-processing)

If the validation requirement does not exist in the current Buf Schema, its possible the latest version of Inventory API with the validation change has not been rolled out. Escalated to the Management Fabric Kessel team to promote the service and restore fucntion.

If the request is being denied for a valid reason, the consumer will not continue processing further messages by design. The message will need to be skipped to continue processing. To capture the event data and skip the message, see [Skipping Offsets to Restore Processing](#skipping-offsets-to-restore-processing)

### Skipping Offsets to Restore Processing

> [!WARNING]
> Any efforts to skip messages should require a Kessel team members involvement, you should use Caution when Skipping Messages in a topic. Skipping messages means a resource will not be created/updated/deleted in Kessel Inventory and could lead to consistency issues down the road. Ensure service providers are aware of the issue to ensure they perform schema and API validation prior to publishing events.

To restore services due to a message that cannot be processed, update the Inventory Consumers offset to skip the bad message allowing it to continue to process any messages in the queue after it. Capturing the event for the service provider is also recommended to show the exact issue and capture info about the resource if needed.

To Update the Offset:

1. Determine the topic that the failing message comes from; the topic name and offset information are available in the error logs

```bash
# Example Error Log
ERROR ts=2025-09-08T04:33:44Z caller=log/log.go:30 service.name=inventory-consumer service.version=0.1.0 trace.id= span.id= subsystem=inventoryConsumer msg=error processing message: topic=host-inventory.hbi.hosts partition=0 offset=10
```

2. Spin up the Kessel Debug container to connect to Kafka

> [!NOTE]
> Kessel Engineers do not have permissions to run containers in production. AppSRE will need to assist in running the container and if access can't be granted, will need to run through these steps for you.

```bash
oc process --local \
    -f https://raw.githubusercontent.com/project-kessel/inventory-api/refs/heads/main/tools/kessel-debug-container/kessel-debug-deploy.yaml \
    -p ENV=prod | oc apply -f -
```

3. Acess the Kessel Debug container and configure

```bash
oc rsh kessel-debug

# Setup Kafka env vars
source /usr/local/bin/env-setup.sh
```

(For more on the Kessel Debug container, check out the [README](https://github.com/project-kessel/inventory-api/tree/main/tools/kessel-debug-container#running-the-debug-container))
4. Capture the event message for the failing offset

```bash
# confirm current offset and lag -- the current offset should be close to, if not the message directly before the offset mentioned in logs
./bin/kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP_SERVERS --command-config $KAFKA_AUTH_CONFIG --group kic --describe

# Example Output
GROUP    TOPIC                    PARTITION  CURRENT-OFFSET  LOG-END-OFFSET
kic      outbox.event.hbi.hosts   0          9               50
```

In the above output, `CURRENT-OFFSET` indicates the last message offset processed, `LOG-END-OFFSET` captures that last offset that exists in the topic. Based on the current offset, the likely culprit is offset `10`, we can look at that message by consuming from the topic and searching for that offset

```bash
./bin/kafka-console-consumer.sh --topic <TOPIC-FROM-OUTPUT> --bootstrap-server $KAFKA_CONNECT_BOOTSTRAP_SERVERS --from-beginning --property print.key=true --property print.headers=true --property print.offset=true | grep Offset:<OFFSET-NUMBER>
```

This will print out the event key, event headers, event offset number and the entire message including message schema. Capture all of this data for records in case any of it is pertinent to the Kessel team or the service provider affected.


5. Update the offset for the Inventory Consumer Group

```bash
# confirm current offset and lag -- the current offset should be close to, if not the message directly before the offset mentioned in logs
./bin/kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP_SERVERS --command-config $KAFKA_AUTH_CONFIG --group kic --describe

# shift to next offset to skip the bad message
./bin/kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP_SERVERS --command-config $KAFKA_AUTH_CONFIG --group kic --reset-offsets --shift-by 1 --execute --topic <SERVICE-PROVIDER-TOPIC-NAME>
```

The Inventory Consumer should move to the next message in the queue after completing and should continue processing as normal. Note, the `kafka-consumer-groups.sh` command generally expects the consumer to not be active in order to complete. It may be required to scale the deployment down to 0 replicas to complete this step. Consumer failures have a retry loop with backoff, executing the command in those waiting periods generally is sufficient.

If scaling down is needed: `oc patch app kessel-inventory-consumer --type='json' -p='[{"op": "replace", "path": "/spec/deployments/0/replicas", "value":0}]'`

Make sure to scale back up after executing the offset update: `oc patch app kessel-inventory-consumer --type='json' -p='[{"op": "replace", "path": "/spec/deployments/0/replicas", "value":3}]'`

If the problem persists on subsequent messages, this process would need to be repeated until all failed messages have been skipped.

4. Clean Up

Once done, make sure to remove the Kessel Debug container

```bash
# after exiting from your rsh session
oc process --local \
    -f https://raw.githubusercontent.com/project-kessel/inventory-api/refs/heads/main/tools/kessel-debug-container/kessel-debug-deploy.yaml \
    -p ENV=prod | oc apply -f -
```
