#!/bin/bash
# BONUS: Automated backup for Swarm state and PostgreSQL
set -euo pipefail
BACKUP_DIR="/backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "=== Backing up Swarm state ==="
sudo cp -r /var/lib/docker/swarm "$BACKUP_DIR/swarm"

echo "=== Backing up PostgreSQL ==="
PGCONTAINER=$(docker ps -q -f name=app_postgres)
if [ -n "$PGCONTAINER" ]; then
  docker exec "$PGCONTAINER" pg_dump -U appuser appdb > "$BACKUP_DIR/postgres-dump.sql"
  echo "DB dump saved: $BACKUP_DIR/postgres-dump.sql"
fi

echo "=== Backup complete: $BACKUP_DIR ==="
ls -la "$BACKUP_DIR"

# Cleanup backups older than 30 days
find /backup -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;
echo "Old backups cleaned up"
