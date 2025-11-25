#!/usr/bin/env bash
docker compose exec kafkacat kcat -b kafka:9092 -C -t employees_user_info -o beginning -q
