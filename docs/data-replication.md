# Data Replication

```
CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    NEW.modified_at = NOW();
    RETURN NEW;
  END;
$$;

CREATE TRIGGER player_with_position_updated_at_modtime BEFORE UPDATE ON player_with_position FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();
```

## Join the streams together

```
CREATE TABLE tbl_player_with_position WITH (
  KAFKA_TOPIC='test.player_with_position',
  VALUE_FORMAT='avro'
) AS
  SELECT
    players.id AS "id",
    players.no AS "no",
    players.name AS "name",
    positions.position AS "position"
  FROM tbl_test_players players
  JOIN tbl_test_positions positions ON positions.id = players.position_id
  EMIT CHANGES;
```

```
DROP TABLE tbl_player_with_position;
```

## Creates a Debezium source connector

### Table Player with Position

```
CREATE SOURCE CONNECTOR test_player_with_position_connector WITH (
  'connector.class' = 'io.confluent.connect.jdbc.JdbcSinkConnector',
  'connection.url' = 'jdbc:postgresql://debezium_postgres_14:5432/test?stringtype=unspecified',
  'connection.user' = 'rendiriz',
  'connection.password' = 'enterpostgres',
  'table.name.format' = 'player_with_position',
  'topics' = 'test.player_with_position',
  'auto.create' = 'true',
  'auto.evolve' = 'true',
  'transforms' = 'unwrap',
  'transforms.unwrap.type' = 'io.debezium.transforms.ExtractNewRecordState',
  'transforms.unwrap.drop.tombstones' = 'false',
  'transforms.unwrap.delete.handling.mode' = 'rewrite',
  'pk.fields' = 'id',
  'pk.mode' = 'record_key',
  'insert.mode' = 'upsert',
  'delete.enabled' = 'true',
  'key.converter' = 'org.apache.kafka.connect.converters.IntegerConverter',
  'key.converter.schema.registry.url' = 'http://schema-registry:8081',
  'key.converter.schemas.enable' ='false',
  'value.converter' = 'io.confluent.connect.avro.AvroConverter',
  'value.converter.schema.registry.url' = 'http://schema-registry:8081',
  'value.converter.schemas.enable' ='true'
);
```

Additional

```
'delete.retention.ms' = '100',
'transforms' = 'unwrap,TimestampConverter,RenameField',
'transforms.unwrap.type' = 'io.debezium.transforms.ExtractNewRecordState',
'transforms.unwrap.drop.tombstones' = 'false',
'transforms.unwrap.delete.handling.mode' = 'rewrite',
'transforms.RenameField.type' = 'org.apache.kafka.connect.transforms.ReplaceField$Value',
'transforms.RenameField.renames' = 'no:NO,name:NAME,position:POSITION,modified_at:MODIFIED_AT',
'transforms.TimestampConverter.type' = 'org.apache.kafka.connect.transforms.TimestampConverter$Value',
'transforms.TimestampConverter.format' = 'yyyy-MM-dd HH:mm:ss.SSS',
'transforms.TimestampConverter.target.type' = 'string',
'key.converter.schema.registry.url' = 'http://schema-registry:8081',
'key.converter' = 'org.apache.kafka.connect.storage.StringConverter',
'key.converter.schemas.enable' ='false',
'value.converter.schema.registry.url' = 'http://schema-registry:8081',
'value.converter' = 'io.confluent.connect.avro.AvroConverter',
'value.converter.schemas.enable' ='true',
'config.action.reload' = 'restart',
'errors.log.enable' = 'true',
'errors.log.include.messages' = 'true',
'print.key' = 'true',
'errors.tolerance' = 'all'
```

```
DESCRIBE CONNECTOR test_player_with_position_connector;
```

```
DROP CONNECTOR test_player_with_position_connector;
```
