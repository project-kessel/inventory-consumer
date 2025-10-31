# Service Provider Replication Failure Guide

Kessel consumer processing failures during replication are generally related to invalid or missing data in the event headers or the outbox payload (event) that are required for Kessel to facilitate replicating your resources and defining relationships. Remediating these issues will generally require AppSRE or Management Fabric Kessel team to alleviate the error, but the fix could potentially impact consistency for a resource and therefore customer. This guide will walk you through some potential errors, what they mean, and how you can avoid them as a service provider.

Related Alerts:
- `<ServiceName>KesselConsumerProcessingFailures`

## Schema/API Validation Related Issues

When a message is processed by the Kessel Inventory Consumer, it leverages the Kessel Inventory API client to create/delete the resource via API quest. Validation of requests for Kessel Inventory API occur at two levels:
1. Schema validation: Does the request data contain all the required data as outlined by the resource type for your service? [schema definition](https://github.com/project-kessel/inventory-api/tree/main/data/schema/resources)?
2. API Validation: Does the request data contain all the required data by the API to facilitate the request?

### Schema Validation Errors

**Example Error in Kessel Inventory Consumer Logs**

```
msg=Error processing request (max attempts reached: 4): failed to report resource: rpc error: code = InvalidArgument desc = missing 'common' field in payload - schema for 'host' has required fields
```

**Reason**

The Kessel Inventory API request made by the Kessel Inventory Consumer has failed schema validation for the particular resource. The request is crafted directly from the payload contents of a Kafka message produced by Debezium from your outbox table. If data is missing from the outbox write that is required for the specific resources schema, the request will fail.

**Verify and Remediate**

Schemas for all resources accepted by Kessel Inventory are defined by their respective service provider in the Kessel Inventory API repo: [Link](https://github.com/project-kessel/inventory-api/tree/main/data/schema/resources). Review the schema and ensure it is accurate for your services' needs.

If the request is being denied for a valid reason, the consumer will not continue processing further messages by design and will require AppSRE/Management Fabric Kessel team to skip the message. This means this event will not be replicated to Kessel and should be resubmitted by the service provider to ensure the replication. The Kessel team can help provide details on the failed message.

If the request is being denied for an invalid reason, meaning the schema files in Github do not reflect the reason for failure, this could be do to a schema mismatch which will require the Management Fabric Kessel team to update the schema loaded with Kessel to remediate the issue. In this scenario, once the new schema is set, the message will process and continue on.

### Kessel Inventory Consumer fails to Create/Modify a Resource due to API Validation Failures

**Example Error in Kessel Inventory Consumer Logs**

```bash
msg=request failed: failed to report resource: rpc error: code = InvalidArgument desc = validation error:
- reporter_type: value length must be at least 1 characters [string.min_len]
- reporter_type: value does not match regex pattern `^[A-Za-z0-9_-]+$` [string.pattern]
- reporter_instance_id: value length must be at least 1 characters [string.min_len]
- representations.metadata.local_resource_id: value length must be at least 1 characters [string.min_len]
- representations.metadata.api_href: value length must be at least 1 characters [string.min_len]
```

**Reason**

The Kessel Inventory API request made by the Kessel Inventory Consumer has failed API validation. The request is crafted directly from the payload contents of a Kafka message produced by Debezium from your outbox table. If data is missing from the outbox write that is required for the specific resources schema, the request will fail.

**Verify and Remediate**

Kessel Inventory API validation is built into the protobuf files used to generate the API. Any requirements for a request can be found in the [Buf Schema Registry](https://buf.build/project-kessel/inventory-api/docs/main:kessel.inventory.v1beta2).

For the Kessel Inventory Consumer, we are concerned with our two Resource request types:

[ReportResourceRequest](https://buf.build/project-kessel/inventory-api/docs/main:kessel.inventory.v1beta2#kessel.inventory.v1beta2.ReportResourceRequest)

[DeleteResourceRequest](https://buf.build/project-kessel/inventory-api/docs/main:kessel.inventory.v1beta2#kessel.inventory.v1beta2.DeleteResourceRequest)

The supported resource types can be found in the [schemas folder](https://github.com/project-kessel/inventory-api/tree/main/data/schema/resources)

Review the validation requirements for the request fields (as denoted by `buf.validate.field` in the request fields). If the validation errors in the pod logs match the validation requirements, then the payload does not meet the API requirements and cannot be processed. The consumer will not continue processing further messages by design and will require AppSRE/Management Fabric Kessel team to skip the message. This means this event will not be replicated to Kessel and should be resubmitted by the service provider to ensure the replication. The Kessel team can help provide details on the failed message.

If the validation requirement does not exist in the current Buf Schema, its possible the latest version of Kessel Inventory API with the validation change has not been rolled out. Escalate to the Management Fabric Kessel team to promote the service and restore fucntion.
