#!/bin/bash

HANDLER_NAME="$1"
echo "Lambda handler: $HANDLER_NAME"

echo "Starting Traccar..."
java -jar /opt/traccar/tracker-server.jar /opt/traccar/conf/traccar.xml &

# Wait for Traccar to boot
while ! curl -s http://localhost:8082/api/server >/dev/null; do
  echo "Waiting for Traccar to be ready..."
  sleep 1
done

echo "✅ Traccar is running."

# Now hand control back to Lambda runtime
exec /lambda-entrypoint.sh "$@"
