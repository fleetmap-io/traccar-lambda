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

  EVENT_BODY=$(echo "$RESPONSE" | sed -n '/^\r$/,$p' | tail -n +2)
  echo "event: $EVENT_BODY"

  HTTP_METHOD=$(echo "$EVENT_BODY" | jq -r '.requestContext.http.method // "GET"')
  REQUEST_PATH=$(echo "$EVENT_BODY" | jq -r '.rawPath // "/"')
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

  echo "$(date '+%T') ✅ Traccar response: $TRACCAR_RESPONSE"

  # Escape Traccar response properly for embedding as JSON string
  ESCAPED_BODY=$(echo "$TRACCAR_RESPONSE" | jq -Rs .)

  # Wrap in Lambda Function URL-compatible format
  FINAL_RESPONSE=$(jq -n \
    --argjson body "$ESCAPED_BODY" \
    --argjson isBase64Encoded false \
    --argjson statusCode 200 \
    --arg contentType "application/json" \
    '{
      statusCode: $statusCode,
      headers: {
        "Content-Type": $contentType
      },
      body: $body,
      isBase64Encoded: $isBase64Encoded
    }')

  # Log and return
  echo "📤 Returning final response to Lambda:" >&2
  echo "$FINAL_RESPONSE" >&2

  curl -s -X POST \
    "http://127.0.0.1:9001/2018-06-01/runtime/invocation/$REQUEST_ID/response" \
    -H "Content-Type: application/json" \
    -d "$FINAL_RESPONSE"
done
