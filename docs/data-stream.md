# Database Test

## Creates a Debezium source connector

### Table Positions

```
CREATE SOURCE CONNECTOR test_position_connector WITH (
  'connector.class' = 'io.debezium.connector.postgresql.PostgresConnector',
  'database.hostname' = 'debezium_postgres_14',
  'database.port' = '5432',
  'database.user' = 'postgres-user',
  'database.password' = 'postgres-pw',
  'database.dbname' = 'test',
  'database.server.name' = 'test',
  'table.whitelist' = 'public.positions',
  'topics' = 'test.public.positions',
  'transforms' = 'unwrap',
  'transforms.unwrap.type' = 'io.debezium.transforms.ExtractNewRecordState',
  'transforms.unwrap.drop.tombstones' = 'false',
  'transforms.unwrap.delete.handling.mode' = 'rewrite',
  'database.history.kafka.bootstrap.servers' = 'http://kafka:9092',
  'database.history.kafka.topic' = 'test.public.positions',
  'include.schema.changes' = 'true',
  'slot.name' = 'test_position_slot',
  'max.queue.size' = '81290',
  'max.batch.size' = '20480',
  'key.converter' = 'io.confluent.connect.avro.AvroConverter',
  'value.converter' = 'io.confluent.connect.avro.AvroConverter',
  'key.converter.schema.registry.url' = 'http://schema-registry:8081',
  'value.converter.schema.registry.url' = 'http://schema-registry:8081',
  'snapshot.mode' = 'exported'
);
```

```
DESCRIBE CONNECTOR test_position_connector;
```

```
DROP CONNECTOR test_position_connector;
```

### Table Players

```
CREATE SOURCE CONNECTOR test_player_connector WITH (
  'connector.class' = 'io.debezium.connector.postgresql.PostgresConnector',
  'database.hostname' = 'debezium_postgres_14',
  'database.port' = '5432',
  'database.user' = 'postgres-user',
  'database.password' = 'postgres-pw',
  'database.dbname' = 'test',
  'database.server.name' = 'test',
  'table.whitelist' = 'public.players',
  'topics' = 'test.public.players',
  'transforms' = 'unwrap',
  'transforms.unwrap.type' = 'io.debezium.transforms.ExtractNewRecordState',
  'transforms.unwrap.drop.tombstones' = 'false',
  'transforms.unwrap.delete.handling.mode' = 'rewrite',
  'database.history.kafka.bootstrap.servers' = 'http://kafka:9092',
  'database.history.kafka.topic' = 'test.public.players',
  'include.schema.changes' = 'true',
  'slot.name' = 'test_player_slot',
  'max.queue.size' = '81290',
  'max.batch.size' = '20480',
  'key.converter' = 'io.confluent.connect.avro.AvroConverter',
  'value.converter' = 'io.confluent.connect.avro.AvroConverter',
  'key.converter.schema.registry.url' = 'http://schema-registry:8081',
  'value.converter.schema.registry.url' = 'http://schema-registry:8081',
  'snapshot.mode' = 'exported'
);
```

```
DESCRIBE CONNECTOR test_player_connector;
```

```
DROP CONNECTOR test_player_connector;
```

### Show Connector

```
SHOW CONNECTORS;
```

## Create topic if not available

Create topic on [Control Center](http://localhost:9021/)

### Schema Table Positions

```
{
  "connect.name": "test.public.positions.Value",
  "fields": [
    {
      "name": "id",
      "type": "int"
    },
    {
      "default": null,
      "name": "no",
      "type": [
        "null",
        "string"
      ]
    },
    {
      "default": 0,
      "name": "modified_at",
      "type": [
        {
          "connect.default": 0,
          "connect.name": "io.debezium.time.MicroTimestamp",
          "connect.version": 1,
          "type": "long"
        },
        "null"
      ]
    },
    {
      "default": null,
      "name": "__deleted",
      "type": [
        "null",
        "string"
      ]
    }
  ],
  "name": "Value",
  "namespace": "test.public.positions",
  "type": "record"
}
```

### Schema Table Players

```
{
  "connect.name": "test.public.players.Value",
  "fields": [
    {
      "name": "id",
      "type": "int"
    },
    {
      "name": "position_id",
      "type": "int"
    },
    {
      "default": null,
      "name": "no",
      "type": [
        "null",
        "string"
      ]
    },
    {
      "default": null,
      "name": "name",
      "type": [
        "null",
        "string"
      ]
    },
    {
      "default": 0,
      "name": "modified_at",
      "type": [
        {
          "connect.default": 0,
          "connect.name": "io.debezium.time.MicroTimestamp",
          "connect.version": 1,
          "type": "long"
        },
        "null"
      ]
    },
    {
      "default": null,
      "name": "__deleted",
      "type": [
        "null",
        "string"
      ]
    }
  ],
  "name": "Value",
  "namespace": "test.public.players",
  "type": "record"
}
```

## Create the ksqlDB source streams and tables

### Table Positions

```
CREATE STREAM strm_test_positions WITH (
  KAFKA_TOPIC = 'test.public.positions',
  VALUE_FORMAT = 'avro',
  TIMESTAMP = 'modified_at'
);
```

```
DROP STREAM strm_test_positions;
```

```
CREATE TABLE tbl_test_positions AS
  SELECT
    id,
    LATEST_BY_OFFSET(position) AS position,
    LATEST_BY_OFFSET(modified_at) AS modified_at
  FROM strm_test_positions
  GROUP BY id
  EMIT CHANGES;
```

```
DROP TABLE tbl_test_positions;
```

### Table Players

```
CREATE STREAM strm_test_players WITH (
  KAFKA_TOPIC = 'test.public.players',
  VALUE_FORMAT = 'avro',
  TIMESTAMP = 'modified_at'
);
```

```
DROP STREAM strm_test_players;
```

```
CREATE TABLE tbl_test_players AS
  SELECT
    id,
    LATEST_BY_OFFSET(position_id) AS position_id,
    LATEST_BY_OFFSET(no) AS no,
    LATEST_BY_OFFSET(name) AS name,
    LATEST_BY_OFFSET(modified_at) AS modified_at
  FROM strm_test_players
  GROUP BY id
  EMIT CHANGES;
```

```
DROP TABLE tbl_test_players;
```

### Join the streams together

Total player by position id

```
CREATE TABLE tbl_test_total_player_by_position_id AS
  SELECT
		players.position_id,
		COUNT(players.position_id) AS total
	FROM strm_test_players players
	GROUP BY players.position_id
	EMIT CHANGES;
```

Total position by player

```
CREATE TABLE tbl_test_total_position_by_player WITH (
	KAFKA_TOPIC='test.total_position_by_player',
	VALUE_FORMAT='json'
) AS
  SELECT
    positions.id AS id,
    positions.position AS position,
    COALESCE(players.total, CAST(0 AS BIGINT)) AS total
  FROM tbl_test_positions positions
  LEFT JOIN tbl_test_total_player_by_position_id AS players ON players.position_id = positions.id
  EMIT CHANGES;
```
