#!/usr/bin/env bash

set -x

# register a connector
curl -X POST -H "Content-Type: application/json" --data @connector/source-connector-mysql.json http://localhost:8083/connectors

# view the connector
# curl -s http://localhost:8083/connectors | jq -r .
# curl -s http://localhost:8083/connectors/employees-mysql-connector/status | jq -r '.'

# validate
# curl -X PUT -H "Content-Type: application/json" --data @connector/debezium-mysql-validate.json http://localhost:8083/connector-plugins/io.debezium.connector.mysql.MySqlConnector/config/validate | jq -r '.'
