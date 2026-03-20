# Swarm Operations & Troubleshooting (Part 5)

## Task 5.1: Rolling Updates & Rollbacks

### 1. Zero-Downtime Rolling Update
```bash
docker service update --image nginx:1.25-alpine app_backend
docker service ps app_backend
```
Our config uses `order: start-first` — new container starts before old stops. At no point are there fewer than 3 healthy replicas.

### 2. Simulate Failed Deployment
```bash
docker service update --image ghcr.io/fake/broken:v1 app_backend
```
Swarm cannot pull the image, new tasks fail. `failure_action: rollback` triggers automatic rollback to previous working image.

### 3. Update Parameters

| Parameter | Value | Purpose |
|-----------|-------|---------|
| parallelism | 2 | Update 2 tasks per batch |
| delay | 10s | Wait between batches |
| failure_action | rollback | Auto-revert on failure |
| monitor | 30s | Watch new task before declaring success |
| max_failure_ratio | 0.25 | Tolerate 25% failures |
| order | start-first | Zero downtime |

### 4. Manual Rollback
```bash
docker service rollback app_backend
```

## Task 5.2: Troubleshooting Scenarios

### Scenario 1: Replicas Running But Requests Failing
```bash
docker service ps app_backend --no-trunc
docker inspect --format='{{json .State.Health}}' CONTAINER_ID
docker service logs app_backend --tail 50
docker service update --force app_backend     # Force restart
```

### Scenario 2: Services Stuck in Starting
```bash
docker service ps app_backend --no-trunc
docker inspect TASK_ID --format '{{.Status.Err}}'
```

| Error | Cause | Fix |
|-------|-------|-----|
| no suitable node | Constraints not met | Check node labels |
| insufficient resources | Not enough CPU/RAM | Lower limits or add nodes |
| secret not found | Secret missing | Run create-secrets.sh |
| non-zero exit (1) | App crashes | Check service logs |

## Task 5.3: Cluster Management
```bash
docker swarm join-token worker                    # Get join token
docker node update --availability drain NODE      # Drain for maintenance
docker node update --availability active NODE     # Return to service
docker node promote NODE                          # Worker to Manager
docker node demote NODE                           # Manager to Worker
docker swarm init --force-new-cluster --advertise-addr IP  # Recover quorum
```

### Backup Swarm State
```bash
sudo systemctl stop docker
sudo cp -r /var/lib/docker/swarm /backup/swarm-$(date +%Y%m%d)
sudo systemctl start docker
```
