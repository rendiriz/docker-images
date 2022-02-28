# Confluent Hub Components

## Get the connectors

To get started, download the connectors to a fresh directory. The easiest way to do this is by using [confluent-hub](https://docs.confluent.io/current/connect/managing/confluent-hub/client.html).

Postgres Debezium connector:

```
confluent-hub install --component-dir confluent-hub-components --no-prompt debezium/debezium-connector-postgresql:1.7.1
```

MongoDB Debezium connector:

```
confluent-hub install --component-dir confluent-hub-components --no-prompt debezium/debezium-connector-mongodb:1.7.1
```

Elasticsearch connector:

```
confluent-hub install --component-dir confluent-hub-components --no-prompt confluentinc/kafka-connect-elasticsearch:11.1.8
```

Avro Converter connector:

```
confluent-hub install --component-dir confluent-hub-components --no-prompt confluentinc/kafka-connect-avro-converter:7.0.1
```
