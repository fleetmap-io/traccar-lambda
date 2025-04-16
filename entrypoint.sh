#!/bin/bash
set -eo pipefail

echo "$(date '+%T') 🔧 Starting Traccar..."
java -jar /opt/traccar/tracker-server.jar /opt/traccar/conf/traccar.xml &

# Wait for Traccar
while ! curl -s http://localhost:8082/api/server >/dev/null; do
  echo "$(date '+%T') ⏳ Waiting for Traccar to be ready..."
  sleep 1
done

echo "$(date '+%T') ✅ Traccar is running."

while true; do
  RESPONSE=$(curl -s -i http://127.0.0.1:9001/2018-06-01/runtime/invocation/next)
  REQUEST_ID=$(echo "$RESPONSE" | grep -i Lambda-Runtime-Aws-Request-Id | awk '{print $2}' | tr -d '\r')

  echo "response: $RESPONSE"
  EVENT_BODY=$(echo "$RESPONSE" | sed -n '/^\r$/,$p' | tail -n +2)
  echo "event: $EVENT_BODY"

  HTTP_METHOD=$(echo "$EVENT_BODY" | jq -r '.httpMethod // empty' 2>/dev/null)
  HTTP_METHOD=${HTTP_METHOD:-GET}

  echo "🧭 HTTP method resolved to: $HTTP_METHOD" >&2

  REQUEST_PATH=$(echo "$EVENT_BODY" | jq -r '.path // "/"')
  REQUEST_PAYLOAD=$(echo "$EVENT_BODY" | jq -r '.body // ""')

  echo "$(date '+%T') ➡️  Forwarding $HTTP_METHOD to http://localhost:8082$REQUEST_PATH" >&2

  if [ "$HTTP_METHOD" == "GET" ]; then
    TRACCAR_RESPONSE=$(curl -s -X GET "http://localhost:8082$REQUEST_PATH")
  else
    TRACCAR_RESPONSE=$(curl -s -X "$HTTP_METHOD" "http://localhost:8082$REQUEST_PATH" \
      -H "Content-Type: application/json" \
      -d "$REQUEST_PAYLOAD")
  fi

  CURL_EXIT=$?
  if [ $CURL_EXIT -ne 0 ]; then
    echo "$(date '+%T') ❌ curl to Traccar failed (exit $CURL_EXIT)" >&2
    TRACCAR_RESPONSE='{"error":"Traccar not responding"}'
  fi

  echo "$(date '+%T') ✅ Traccar response:" >&2
  echo "$TRACCAR_RESPONSE" | jq . >&2 2>/dev/null || echo "$TRACCAR_RESPONSE" >&2

  curl -s -X POST \
    "http://127.0.0.1:9001/2018-06-01/runtime/invocation/$REQUEST_ID/response" \
    -d "$TRACCAR_RESPONSE"
done
