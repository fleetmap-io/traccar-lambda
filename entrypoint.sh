#!/bin/bash

echo "Starting Traccar..."
java -jar /opt/traccar/tracker-server.jar /opt/traccar/conf/traccar.xml &

# Wait for Traccar to boot
#while ! curl -s http://localhost:8082/api/server >/dev/null; do
#  echo "Waiting for Traccar to be ready..."
#  sleep 1
#done

echo "✅ Traccar is running."

function handler () {
  echo "function handler called"
}


while true; do
  # Get the next invocation
  RESPONSE=$(curl -s -i http://127.0.0.1:9001/2018-06-01/runtime/invocation/next)
  REQUEST_ID=$(echo "$RESPONSE" | grep -i Lambda-Runtime-Aws-Request-Id | awk '{print $2}' | tr -d '\r')

  echo "➡️  Invocation received: $REQUEST_ID" >&2

  # Call your handler and capture the response
  RESPONSE_BODY=$(handler)

  # Send the response
  curl -s -X POST "http://127.0.0.1:9001/2018-06-01/runtime/invocation/$REQUEST_ID/response" \
       -d "$RESPONSE_BODY"
done
