#!/bin/bash
echo "$(date '+%T') Starting traccar lambda v2 ..."
/opt/traccar/jre/bin/java -jar /opt/traccar/tracker-server.jar /opt/traccar/conf/traccar.xml &
sleep 4
echo "$(date '+%T') Entering infinite while ..."

while true; do
  RESPONSE=$(curl -s -i http://127.0.0.1:9001/2018-06-01/runtime/invocation/next)
  REQUEST_ID=$(echo "$RESPONSE" | grep -i Lambda-Runtime-Aws-Request-Id | awk '{print $2}' | tr -d '\r')
  EVENT_BODY=$(echo "$RESPONSE" | sed -n '/^\r$/,$p' | tail -n +2)
  HTTP_METHOD=$(echo "$EVENT_BODY" | jq -r '.requestContext.http.method // "GET"')
  REQUEST_PATH=$(echo "$EVENT_BODY" | jq -r '.rawPath // "/"')
  REQUEST_PAYLOAD=$(echo "$EVENT_BODY" | jq -r '.body // ""')
  COOKIE_HEADER=$(echo "$EVENT_BODY" | jq -r '.headers."cookie" // empty')

  FULL_URL="http://localhost:8082$REQUEST_PATH"
  RAW_QUERY=$(echo "$EVENT_BODY" | jq -r '.rawQueryString // ""')
  if [ -n "$RAW_QUERY" ]; then
    FULL_URL="$FULL_URL?$RAW_QUERY"
  fi
  echo "$(date '+%T') $EVENT_BODY ➡️ $HTTP_METHOD $FULL_URL"

  if [ "$HTTP_METHOD" == "GET" ]; then
    TRACCAR_RESPONSE=$(curl -s -i -X GET "$FULL_URL" -H "Cookie: $COOKIE_HEADER")
  else
    TRACCAR_RESPONSE=$(curl -s -i -X "$HTTP_METHOD" "$FULL_URL" \
      -H "Content-Type: application/json" \
      -H "Cookie: $COOKIE_HEADER" \
      -d "$REQUEST_PAYLOAD")
  fi

  CURL_EXIT=$?
  if [ $CURL_EXIT -ne 0 ]; then
    echo "$(date '+%T') ❌ curl to Traccar failed (exit $CURL_EXIT)"
    TRACCAR_RESPONSE='{"error":"Traccar not responding"}'
  fi

  HEADERS=$(echo "$TRACCAR_RESPONSE" | sed '/^\r$/q')
  BODY=$(echo "$TRACCAR_RESPONSE" | sed '1,/^\r$/d')

  STATUS_CODE=$(echo "$TRACCAR_RESPONSE" | head -n 1 | awk '{print $2}')
  HEADERS_JSON=$(echo "$HEADERS" | grep -E '^[A-Za-z0-9-]+:' | \
    awk -F': ' '{printf "{\"%s\":\"%s\"}\n", $1, $2}' | jq -s 'add')

  FINAL_RESPONSE=$(jq -n \
    --arg body "$(echo "$BODY" | jq -Rs .)" \
    --argjson isBase64Encoded false \
    --argjson statusCode "$STATUS_CODE" \
    --argjson headers "$HEADERS_JSON" \
    '{
      statusCode: $statusCode,
      headers: $headers,
      body: $body,
      isBase64Encoded: $isBase64Encoded
    }')


  curl -s -X POST \
    "http://127.0.0.1:9001/2018-06-01/runtime/invocation/$REQUEST_ID/response" \
    -H "Content-Type: application/json" \
    -d "$FINAL_RESPONSE"
done
