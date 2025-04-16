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
