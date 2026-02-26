#!/usr/bin/env bash
set -euo pipefail

QUEUE_URL=${1:?usage: send_orders.sh <queue-url> [count]}
COUNT=${2:-100}

for i in $(seq 1 "$COUNT"); do
  order_id=$(printf "order-%04d" "$i")
  aws sqs send-message \
    --queue-url "$QUEUE_URL" \
    --message-group-id "orders" \
    --message-deduplication-id "$order_id" \
    --message-body "{\"order_id\":\"$order_id\",\"total\":$i}"
done

echo "queued $COUNT orders"
