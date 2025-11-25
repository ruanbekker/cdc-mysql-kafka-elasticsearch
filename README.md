# cdc-mysql-kafka-elasticsearch

Change Data Capture (CDC) Pipeline using MySQL, Kafka, Kafka Connect, and Elasticsearch.

## Overview


```
 ┌───────────────────┐
 │   MySQL Database  │
 └─────┬─────────────┘
       │ (1) Debezium Source Connector reads changes
       ▼
 ┌──────────────────────────┐
 │ Kafka Connect            │
 │ MySQL Source Connector   │
 └─────┬────────────────────┘
       │ Publishes change events
       ▼
 ┌────────────────────────────────┐
 │  Kafka Cluster                 │
 │  Topic:                        │
 │  employees_employees.user_info │
 └──────┬─────────────────────────┘
       │ (2) Elasticsearch Sink Connector reads events
       ▼
 ┌─────────────────────┐
 │ Kafka Connect       │
 │ Elasticsearch Sink  │
 │ Connector           │
 └─────┬───────────────┘
       │ Writes documents
       ▼
 ┌───────────────────────────────┐
 │ Elasticsearch Cluster         │
 │ Index:                        │
 │ employees_employees.user_info │
 └───────────────────────────────┘
```

1. MySQL Source Connector
  - Monitors your MySQL table(s) for inserts, updates, and deletes.
  - Sends these change events as messages to Kafka topics.

2. Kafka Topics
  - Kafka acts as the central event bus.
  - The topic stores the data in the format sent by the source connector.

3. Elasticsearch Sink Connector
  - Consumes the messages from Kafka.
  - Transforms them (optionally via SMTs like ExtractNewRecordState) to keep only relevant fields.
  - Writes the processed data to Elasticsearch indices.

Some terms:

- Source connector → pushes data into Kafka (Debezium MySQL connector)
- Sink connector → pulls data from Kafka (Elasticsearch connector)
- Kafka → central message bus / buffer
- SMT (Single Message Transform) → optional transformation between source and sink

## Getting Started

Boot the stack:

```bash
docker compose up -d
```

Register the source connector (sends data from mysql into kafka):

```bash
curl -X POST -H "Content-Type: application/json" --data @connector/source-connector-mysql.json http://localhost:8083/connectors
```

Verify that the connector was registered:

```bash
curl -s http://localhost:8083/connectors
["employees-mysql-connector"]
```

We can also view the status of that connector (if there are any problems with it, it will display here):

```bash
curl -s http://localhost:8083/connectors/employees-mysql-connector/status | jq .
{
  "name": "employees-mysql-connector",
  "connector": {
    "state": "RUNNING",
    "worker_id": "connect:8083"
  },
  "tasks": [
    {
      "id": 0,
      "state": "RUNNING",
      "worker_id": "connect:8083"
    }
  ],
  "type": "source"
}
```

We can view our topics and we should see our topics that the connector will use:

```bash
docker compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list
__consumer_offsets
_schemas
connect-configs
connect-offsets
connect-status
dbhistory.employees
employees_employees.user_info
employees_employees.user_salaries
```

Access the database:

```bash
docker compose exec mysql mysql -uroot -prootpassword
```

View the table:

```bash
mysql> describe employees.user_info;
+------------+--------------+------+-----+-------------------+-------------------+
| Field      | Type         | Null | Key | Default           | Extra             |
+------------+--------------+------+-----+-------------------+-------------------+
| id         | int          | NO   | PRI | NULL              | auto_increment    |
| username   | varchar(100) | NO   |     | NULL              |                   |
| email      | varchar(255) | NO   |     | NULL              |                   |
| created_at | timestamp    | YES  |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
+------------+--------------+------+-----+-------------------+-------------------+
```

Write a database entry:

```bash
mysql> INSERT INTO employees.user_info (username,email) VALUES ('test','test@example.com');
```

Consume the topic:

```bash
docker compose exec kafkacat kcat -b kafka:9092 -C -t employees_employees.user_info -o beginning -q
```

View the event (im only displaying the payload value to shorten it for readability)

```json
{
  "before": null,
  "after": {
    "id": 3,
    "username": "test",
    "email": "test@example.com",
    "created_at": "2025-11-21T08:14:27Z"
  },
  "source": {
    "version": "2.7.0.Final",
    "connector": "mysql",
    "name": "employees",
    "ts_ms": 1763713518000,
    "snapshot": "last_in_data_collection",
    "db": "employees",
    "sequence": null,
    "ts_us": 1763713518000000,
    "ts_ns": 1763713518000000000,
    "table": "user_info",
    "server_id": 0,
    "gtid": null,
    "file": "mysql-bin.000003",
    "pos": 481,
    "row": 0,
    "thread": null,
    "query": null
  },
  "transaction": null,
  "op": "r",
  "ts_ms": 1763713518415,
  "ts_us": 1763713518415157,
  "ts_ns": 1763713518415157000
}
```

When we update a record:

```bash
UPDATE employees.user_info SET email='test.new@example.com' WHERE id=3;
```

We can see the event shows the previous and current value:

```json
  "before": {
    "id": 3,
    "username": "test",
    "email": "test@example.com",
    "created_at": "2025-11-21T08:14:27Z"
  },
  "after": {
    "id": 3,
    "username": "test",
    "email": "test.new@example.com",
    "created_at": "2025-11-21T08:14:27Z"
  },
```

## Elasticsearch

View the indices, you should see no indices yet:

```bash
curl http://localhost:9200/_cat/indices?v
health status index uuid pri rep docs.count docs.deleted store.size pri.store.size dataset.size
--
```

Create the sink connector (consumes data from kafka to elasticsearch):

```bash
curl -X POST -H "Content-Type: application/json" --data @connector/sink-connector-elasticsearch.json http://localhost:8083/connectors
```

Verify that the connector was registered:

```bash
curl -s http://localhost:8083/connectors
["employees-es-sink","employees-mysql-connector"]
```

View the status:

```bash
curl -s http://localhost:8083/connectors/employees-es-sink/status | jq -r
{
  "name": "employees-es-sink",
  "connector": {
    "state": "RUNNING",
    "worker_id": "connect:8083"
  },
  "tasks": [
    {
      "id": 0,
      "state": "RUNNING",
      "worker_id": "connect:8083"
    }
  ],
  "type": "sink"
}
```

We should now see our index `employees_employees.user_info`:

```bash
curl http://localhost:9200/_cat/indices?v
health status index                         uuid                   pri rep docs.count docs.deleted store.size pri.store.size dataset.size
yellow open   employees_employees.user_info sVHnJVwcQpmS7jl7ClF3GA   1   1          3            1     16.1kb         16.1kb       16.1kb
```

View the document:

```bash
curl http://localhost:9200/employees_employees.user_info/_search?pretty
{
  "took" : 45,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 3,
      "relation" : "eq"
    },
    "max_score" : 1.0,
    "hits" : [
      {
        "_index" : "employees_employees.user_info",
        "_id" : "1",
        "_score" : 1.0,
        "_source" : {
          "id" : 1,
          "username" : "alice",
          "email" : "alice@example.com",
          "created_at" : "2025-11-21T08:06:41Z",
          "__deleted" : "false"
        }
      },
      {
        "_index" : "employees_employees.user_info",
        "_id" : "3",
        "_score" : 1.0,
        "_source" : {
          "id" : 3,
          "username" : "test",
          "email" : "test.new@example.com",
          "created_at" : "2025-11-21T08:14:27Z",
          "__deleted" : "false"
        }
      },
      {
        "_index" : "employees_employees.user_info",
        "_id" : "2",
        "_score" : 1.0,
        "_source" : {
          "id" : 2,
          "username" : "bob",
          "email" : "bob@example.com",
          "created_at" : "2025-11-21T08:06:41Z",
          "__deleted" : "false"
        }
      }
    ]
  }
}
```

When we create a new entry into the database:

```bash
INSERT INTO employees.user_info (username,email) VALUES ('frankie','frankie@example.com');
```

We can see it end up in elasticsearch:

```bash
curl 'http://localhost:9200/employees_employees.user_info/_search?q=frankie&pretty'
{
  "took" : 3,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 1,
      "relation" : "eq"
    },
    "max_score" : 1.3862942,
    "hits" : [
      {
        "_index" : "employees_employees.user_info",
        "_id" : "4",
        "_score" : 1.3862942,
        "_source" : {
          "id" : 4,
          "username" : "frankie",
          "email" : "frankie@example.com",
          "created_at" : "2025-11-21T08:39:22Z",
          "__deleted" : "false"
        }
      }
    ]
  }
}
```
