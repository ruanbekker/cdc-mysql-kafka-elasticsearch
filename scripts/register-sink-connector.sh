#!/usr/bin/env bash

# Registers a sink connector (consumes data from kafka)

set -x

curl -X POST -H "Content-Type: application/json" --data @connector/sink-connector-elasticsearch.json http://localhost:8083/connectors

