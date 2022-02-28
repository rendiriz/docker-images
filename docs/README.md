## Start the Postgres Debezium source connectors

```
docker exec -it ksqldb-cli_0_23 ksql http://ksqldb-server:8088
```

```
SET 'auto.offset.reset' = 'earliest';
```
