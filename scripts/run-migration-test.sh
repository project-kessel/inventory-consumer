#!/bin/bash

echo "Setting up Debezium connectors..."
make setup-connectors

echo "Checking connector status..."
make check-connector-status
