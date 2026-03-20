#!/bin/bash
set -euo pipefail
SECRET="${1:?Usage: $0 <name> <value>}"; VALUE="${2:?}"
NEW="${SECRET}_v$(date +%Y%m%d%H%M%S)"
echo "$VALUE" | docker secret create "$NEW" -
for SVC in $(docker service ls -q); do
  docker service inspect "$SVC" --format '{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}' 2>/dev/null \
    | grep -q "\"$SECRET\"" && \
    docker service update --secret-rm "$SECRET" --secret-add "source=$NEW,target=$SECRET" "$SVC" || true
done
docker secret rm "$SECRET" 2>/dev/null || true
echo "Rotated: $SECRET -> $NEW"