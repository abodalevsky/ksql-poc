# Kafka Sink
Experiments how kafka database connector sink can be leveraged by our infrastructure.

## Overview
Connect worker process uses connectors, transforms, and converter plugins
## Start environment
```bash
docker compose up -d
```

to rebuild you must use `docker-compose build` or `docker-compose up --build`.

It will create _bridge network_ with name: [root_directory]_default. To access the network can be used an external lightweight  image, like `alphine` for instance.
```bash
docker run --name alpine --network ksql-poc_default  --rm -it alpine:3.13.5 sh
```

Inside image we need cUrl and psql clients to install them should be ran:
```bash
apk add --no-cache curl postgresql-client
``` 
### List images
```bash
docker ps
CONTAINER ID   IMAGE                                   COMMAND                  CREATED              STATUS                                 PORTS                                        NAMES
1d8f704ff57b   localbuild/connector:0.0.1              "/etc/confluent/dock…"   About a minute ago   Up About a minute (health: starting)   0.0.0.0:8083->8083/tcp, 9092/tcp             connector
bf8e568d9b80   confluentinc/cp-schema-registry:6.0.0   "/etc/confluent/dock…"   9 days ago           Up 2 hours                             0.0.0.0:8081->8081/tcp                       schema-registry
f7c1a826b2be   confluentinc/cp-kafka:6.0.0             "/etc/confluent/dock…"   9 days ago           Up 2 hours                             9092/tcp, 0.0.0.0:29092->29092/tcp           broker
f8d900020968   confluentinc/cp-zookeeper:6.0.0         "/etc/confluent/dock…"   9 days ago           Up 2 hours                             2888/tcp, 0.0.0.0:2181->2181/tcp, 3888/tcp   zookeeper
```

## Step-by-step
### Avro
1. Connect to broker
```bash
docker exec -it broker bash
```
2. Create topic 
```bash
kafka-topics --create --topic quickstart-jdbc-test --bootstrap-server localhost:9092
```
3. Start alpine client
```bash
docker run --name alpine --network ksql-poc_default  --rm -it alpine:3.13.5 sh
```
4. Copy config to alpine
```bash
docker cp ./src/connector/file-sink.config.json alpine:/tmp
```
5. Deploy config to connector service,
```bash 
curl -i -X POST  http://connector:28083/connectors/ -H "Content-Type: application/json" --data "@/tmp/file-sink.config.json"
```
6. Use console avro producer for test
 ```bash
docker exec -it schema-registry kafka-avro-console-producer \
    --bootstrap-server broker:9092 \
    --topic quickstart-jdbc-test \
    --property value.schema='{"type":"record","name":"myrecord","fields":[{"name":"f1","type":"string"}]}'

{"f1":"value1"}
{"f1":"value2"}
{"f1":"value3"}
```
7. File connector will produce output, check it
```bash
docker exec -it connector cat /tmp/jdbc-output.txt
```

## Useful commands
### Kafka service
https://kafka.apache.org/quickstart

#### Connect to kafka container
```bash
docker exec -it broker bash
```

#### Get list of topics
```bash
kafka-topics --list --zookeeper zookeeper:2181
```

#### Get info about topic
```bash
kafka-consumer-groups --bootstrap-server localhost:9092 --all-groups  --describe
```

#### Create and delete topic
```bash
kafka-topics --create --topic topic1 --bootstrap-server localhost:9092
kafka-topics --delete --topic topic1 --bootstrap-server localhost:9092
```

#### Write to topic
```bash
kafka-console-producer --topic topic1 --property "parse.key=true" --property "key.separator=:" --bootstrap-server localhost:9092

kafka-avro-console-producer \
    --bootstrap-server broker:9092 \
    --topic jdbc-test \
    --property value.schema='{"type":"record","name":"myrecord","fields":[{"name":"id","type":"string", "logicalType":"UUID"},{"name":"f1","type":["null", "string"],"default":null}]}'
```

#### Read from topic
```bash
kafka-console-consumer --bootstrap-server localhost:9092 --topic topic1 --from-beginning

kafka-avro-console-consumer --bootstrap-server broker:9092 --topic quickstart-jdbc-test
```
### Connector Service
Configs (properties) located at /etc/kafka


Get config
```bash
curl -X GET -H "Content-Type: application/json"  http://connector:28083/connectors
```

copy config file to docker container (alphine) and run
```bash
docker cp ./src/connector/psql.config.json alphine:/tmp

curl -i -X POST  http://connector:28083/connectors/ -H "Content-Type: application/json" --data "@./psql.config.json"

curl -X GET -H "Content-Type: application/json"  http://connector:28083/connectors/psql-jdbc-sink/status

curl -X DELETE -H "Content-Type: application/json"  http://connector:28083/connectors/psql-jdbc-sink
```

#### Config format
DB PKey is taken from topic value.
```json
{
    "name": "psql-jdbc-sink",
    "config": {
        "name": "psql-jdbc-sink",
        "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
        "tasks.max": "1", /*for distributed mode can be > 1*/
        "topics": "jdbc-test",
        "connection.url": "jdbc:postgresql://postgres:5432/ksinc",
        "connection.user": "postgres",
        "connection.password": "pp",
        "dialect.name": "PostgreSqlDatabaseDialect",
        "table.name.format": "test",
        "auto.create": "false", /*create table if not exists*/
        "errors.log.enable": true,
        "errors.tolerance": "all", /*do not stop on error (in addition deadqueu can be configured) */
        "consumer.override.auto.offset.reset": "latest",
        "pk.mode": "record_value", /*it says that PK is taken from topic value*/
        "pk.field": "id", /*name of field from value*/
        "insert.mode": "upsert" /*mode if key exists (by default insert) fails if duplicate found*/
    }
}
```

Example of message to send: `{"id":"d25f41f4-7379-44c3-9beb-a98861565000","f1":{"string":"second updated text"}}`

If key is taken from value it isn't possible to delete message with a help of _tombstone message_.

DB PKey is taken from kafka topic key.
```json
{
    "name": "psql-ex-jdbc-sink",
    "config": {
        "name": "psql-ex-jdbc-sink",
        "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
        "tasks.max": "1",
        "topics": "jdbc-ex-test",
        "connection.url": "jdbc:postgresql://postgres:5432/ksinc",
        "connection.user": "postgres",
        "connection.password": "pp",
        "dialect.name": "PostgreSqlDatabaseDialect",
        "table.name.format": "test",
        "auto.create": "false",
        "errors.log.enable": true,
        "errors.tolerance": "all",
        "consumer.override.auto.offset.reset": "latest",
        "pk.mode": "record_key", /*PK is taken from key message*/
        "pk.fields": "id",
        "insert.mode": "upsert",
        "delete.enabled": true /*handle tombstone message as delete*/
    }
} 
```
### E2E create connection with PK
1. Create kafka topic `kafka-topics --create --topic jdbc-ex-test --bootstrap-server broker:9092`;
2. Create db from `./src/db-postgre/init.sql`;
3. Create sink connector from `./src/connector/psql-ex.config.json`
```bash
curl -i -X POST  http://connector:28083/connectors/ -H "Content-Type: application/json" --data "@./psql-ex.config.json"
```
4. Open avro producer and specify scheme
it may be run from host via schema-registry guest system `docker exec -it schema-registry`
```bash
kafka-avro-console-producer \
    --bootstrap-server broker:9092 \
    --topic jdbc-ex-test \
    --property key.schema='{"type":"record","name":"myrecordkey","fields":[{"name":"id","type":"string", "logicalType":"UUID"}]}' \
    --property value.schema='{"type":"record","name":"myrecord","fields":[{"name":"f1","type":["null", "string"],"default":null}]}' \
    --property parse.key=true \
    --property key.separator="?"

```
5. Send message(s):
```json
{"id":"d25f41f4-7379-44c3-9beb-a98861565001"}?{"f1":{"string":"3rd text"}}
```
6. To delete record must be sent tombstone message (where value is null), unfortunately it cannot be done from console. But it can be done from kafkacat
Example demonstrate run instance of kafkacat from docker, connect ot network _ksql-poc_default_ which is default for this example.
```bash
docker run -it --network=ksql-poc_default \
    --rm \
    echo "d25f41f4-7379-44c3-9beb-a98861565001:" | \
    kafkacat \
    -b broker:9092 \
    -t jdbc-ex-test \
    -Z -K:
```
UPD: unfortunately does not work with AVRO serializer.


## PSQL
### Useful commands
* list of databases `\l`
* switch to database `\c [db_name]`
* list of table `\dt`
* see DDL `\d+ [table_name]`
### Init
copy init script to container
```bash
docker cp ./src/db-postgre/init.sql alpine:/tmp
```

Prepare infra for PSQL, on alpine image run
```bash
export PGPASSWORD=pp
export PGHOST=postgres
export PGUSER=postgres
psql -f /tmp/init.sql
```


# Links
* [Connector Overview](https://docs.confluent.io/home/connect/userguide.html)
* [Sink Connector](https://docs.confluent.io/kafka-connect-jdbc/current/sink-connector/index.html)
* [Connector properties](https://docs.confluent.io/platform/current/installation/configuration/connect/sink-connect-configs.html)
* [Connector API](https://docs.confluent.io/platform/current/connect/references/restapi.html#connector-plugins)
* [Connector in Docker (tutorial)](https://docs.confluent.io/5.0.0/installation/docker/docs/installation/connect-avro-jdbc.html)
* [Kafka commands](https://gist.github.com/ursuad/e5b8542024a15e4db601f34906b30bb5)
* [Kafka commands (inc Avro)](https://docs.confluent.io/2.0.0/quickstart.html)
* [KSINK DB tutorial](https://www.youtube.com/watch?v=ABOJGB5G35k) and [demo repo](https://github.com/confluentinc/demo-scene/tree/master/kafka-to-database)

