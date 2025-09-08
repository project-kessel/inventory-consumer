# Consumer Message Processing Failures

## Prerequisites

Remediations covered in this guide will require the following:
1) Access to running Inventory API pod logs
2) Access to a running container with Kafka CLI tools (covered in runbooks where needed)
3) Kafka connection information including bootstrap servers and authentication credentials (covered in runbooks where needed)


## Schema/API Validation Related Issues

When a message is processed by the Inventory Consumer, it leverages the Inventory API client to create/delete the resource via API quest. Validation of requests for Inventory API occur at two levels:
1) Schema validation: Does the request data contain all the required data as outlined by the resource types [schema definition](https://github.com/project-kessel/inventory-api/tree/main/data/schema/resources)
2) API Validation: Does the request data contain all the required data by the API to facilitate the request

### Inventory Consumer fails to Create/Modify a Resource due to Schema Validation Errors

**Example Error in Inventory Consumer Logs**

```
msg=Error processing request (max attempts reached: 4): failed to report resource: rpc error: code = InvalidArgument desc = missing 'common' field in payload - schema for 'host' has required fields
```

**Reason**

The Inventory API request made by the Inventory Consumer using the API client has failed schema validation. The request is crafted directly from the payload contents of a Kafka message produced by Debezium from the service providers source database's outbox table. If data is missing from the outbox write that is required for the specific resources schema, the request will fail.

**Verify and Remediate**

You can verify if there is a schema mismatch one of two ways:

1) Check the loaded schema in Inventory API for the specific resource

2) Compare the loaded schema to the expected schema

The schema is deployed via App Interface and is visible in the [`resources-tarball`](https://gitlab.cee.redhat.com/service/app-interface/-/blob/master/resources/insights-prod/kessel-prod/kessel-inventory-schema-configmap.yml?ref_type=heads). You can dump the ConfigMap contents to a tar file and unpack, or for simplicity sakes, you can exec/rsh to an Inventory API pod and review the contents in the container under `/data/schema/resources/`.

Compare the schema validation error to the schema in container:
* If the error matches a validation rule, then the Inventory API pods have the current schema loaded and are properly denying the request.
* If the error does not match a valid rule in the schema, its possible the Inventory API pod has not loaded the current ConfigMap and recycling the pods will trigger them to load the new schema

If the error matches a validation rule but the validation is not expected in the latest schema, compare the schema validation error to the [schema definitions](https://github.com/project-kessel/inventory-api/tree/main/data/schema/resources) in Github. If the schemas do not match, its possible the `resources-tarball` ConfigMap has not been updated with a current version of the tar file and needs to be updated. Once updated, this would resume message processing.

### Inventory Consumer fails to Create/Modify a Resource due to API Validation Failures

**Example Error in Inventory Consumer Logs**

```shell
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

### Skipping Offsets to Restore Processing

> [!WARNING]
> Any efforts to skip messages should require a Kessel team members involvement

To restore services due to a message that cannot be processed, update the Inventory Consumers offset to skip the bad message allowing it to continue to process any messages in the queue after it.

To Update the Offset:

1) Determine the topic that the failing message comes from; the topic name and offset information are available in the error logs

```shell
# Example Error Log
ERROR ts=2025-09-08T04:33:44Z caller=log/log.go:30 service.name=inventory-consumer service.version=0.1.0 trace.id= span.id= subsystem=inventoryConsumer msg=error processing message: topic=host-inventory.hbi.hosts partition=0 offset=0
```

2) Leverage the [ConsoleDot Kafka Debug process](https://inscope.corp.redhat.com/docs/default/component/consoledot-pages/services/kafka/#kafka-debug-pod) to spin up a pod with access to the Platform MQ Kafka cluster

3) Update the offset for the Inventory Consumer Group

```shell
# from the kafka debug pod
/opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP_SERVERS --command-config /opt/kafka/config/authed-kafka.properties --group kic --reset-offsets --shift-by 1 --execute --topic <SERVICE-PROVIDER-TOPIC-NAME>
```

The Inventory Consumer should move to the next message in the queue after completing and should continue processing as normal. Note, the `kafka-consumer-groups.sh` command generally expects the consumer to not be active in order to complete. It may be required to scale the deployment down to 0 replicas to complete this step. Consumer failures have a retry loop with backoff, executing the command in those waiting periods generally is sufficient.

If scaling down is needed: `oc patch app kessel-inventory-consumer --type='json' -p='[{"op": "replace", "path": "/spec/deployments/0/replicas", "value":0}]'`

Make sure to scale back up after executing the offset update: `oc patch app kessel-inventory-consumer --type='json' -p='[{"op": "replace", "path": "/spec/deployments/0/replicas", "value":3}]'`

If the problem persists on subsequent messages, this process would need to be repeated until all failed messages have been skipped.
