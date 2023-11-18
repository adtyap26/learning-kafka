#!/bin/bash

services=(
    "confluent-control-center.service"
    "confluent-schema-registry.service"
    "confluent-ksqldb.service"
    "confluent-kafka-rest.service"
    "confluent-kafka-connect.service"
    "confluent-server.service"
    "confluent-zookeeper.service"
)

for service in "${services[@]}"; do
    echo "Stopping $service now..."
    sudo systemctl stop "$service"
    if [ $? -eq 0 ]; then
        echo "$service stopped  "
    else
        echo "Failed to stop $service"
    fi
done

