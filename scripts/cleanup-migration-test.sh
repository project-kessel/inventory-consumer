#!/bin/bash

echo "Removing Kafka connectors..."
make delete-connectors

echo "Removing replication slots..."
make remove-replication-slots

echo "Cleaning up pods..."
for i in development-inventory-consumer-1 development-inventory-consumer-2 development-inventory-consumer-3 development-kic-connect-1 development-connect-1; do
    podman stop $i
done

for i in development-inventory-consumer-1 development-inventory-consumer-2 development-inventory-consumer-3 development-kic-connect-1; do
    podman rm $i
done

echo "Cleaning up topics..."
for i in host-inventory.hbi.hosts outbox.event.hbi.hosts kessel_kafka_connect_configs kessel_kafka_connect_offsets kessel_kafka_connect_statuses; do
    podman exec development-kafka-1 /bin/sh -c "bin/kafka-topics.sh --bootstrap-server kafka:9093 --delete --topic $i"
done

echo "Cleaning up Inventory DB...this may take a minute"
psql postgres://postgres:yPsw5e6ab4bvAGe5H@localhost:5433/spicedb -f ./development/configs/inventory-cleanup.sql

echo "Removing relationships from SpiceDB...this may take a minute"
zed --endpoint localhost:50051 --insecure --token foobar relationship bulk-delete hbi/host --force

echo "Restarting connect..."
podman start development-connect-1
