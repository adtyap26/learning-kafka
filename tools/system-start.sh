#!/bin/bash

services=(
    "confluent-zookeeper.service"
    "confluent-server.service"
    "confluent-schema-registry.service"
    "confluent-ksqldb.service"
    "confluent-kafka-rest.service"
    "confluent-kafka-connect.service"
    "confluent-control-center.service"
)

for service in "${services[@]}"; do
    echo "Starting $service now..."
    sudo systemctl start "$service"
    if [ $? -eq 0 ]; then
        echo "$service started  "
    else
        echo "Failed to start $service"
    fi
done

