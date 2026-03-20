#!/bin/bash
set -euo pipefail
PORTAINER_URL="${PORTAINER_URL:?}"; PORTAINER_USER="${PORTAINER_USER:?}"; PORTAINER_PASSWORD="${PORTAINER_PASSWORD:?}"
STACK_NAME="${STACK_NAME:-app}"; COMPOSE_FILE="${COMPOSE_FILE:-./docker-compose.yml}"
TOKEN=$(curl -sk "$PORTAINER_URL/api/auth" -H "Content-Type: application/json" \
  -d "{\"Username\":\"$PORTAINER_USER\",\"Password\":\"$PORTAINER_PASSWORD\"}" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['jwt'])")
AUTH="Authorization: Bearer $TOKEN"
ENDPOINT_ID=$(curl -sk "$PORTAINER_URL/api/endpoints" -H "$AUTH" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['Id'])")
SWARM_ID=$(curl -sk "$PORTAINER_URL/api/endpoints/$ENDPOINT_ID/docker/swarm" -H "$AUTH" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['ID'])")
case "${1:-help}" in
  deploy)
    CONTENT=$(python3 -c "import sys,json;print(json.dumps(open('$COMPOSE_FILE').read()))")
    EXISTING=$(curl -sk "$PORTAINER_URL/api/stacks" -H "$AUTH" \
      | python3 -c "import sys,json;[print(s['Id']) for s in json.load(sys.stdin) if s['Name']=='$STACK_NAME']" 2>/dev/null || echo "")
    if [ -n "$EXISTING" ]; then
      curl -sk -X PUT "$PORTAINER_URL/api/stacks/$EXISTING?endpointId=$ENDPOINT_ID" \
        -H "$AUTH" -H "Content-Type: application/json" \
        -d "{\"StackFileContent\":$CONTENT,\"Prune\":true}"
    else
      curl -sk -X POST "$PORTAINER_URL/api/stacks/create/swarm/string?endpointId=$ENDPOINT_ID" \
        -H "$AUTH" -H "Content-Type: application/json" \
        -d "{\"Name\":\"$STACK_NAME\",\"SwarmID\":\"$SWARM_ID\",\"StackFileContent\":$CONTENT}"
    fi ;;
  list) curl -sk "$PORTAINER_URL/api/stacks" -H "$AUTH" | python3 -c "import sys,json;[print(f'{s[\"Id\"]:>4} {s[\"Name\"]}') for s in json.load(sys.stdin)]" ;;
  *) echo "Usage: $0 {deploy|list}" ;;
esac