# Swarm Cluster Operations Runbook

## Adding Nodes
```bash
docker swarm join-token worker
# On new node:
docker swarm join --token SWMTKN-xxx MANAGER_PRIVATE_IP:2377
```

## Removing Nodes
```bash
docker node update --availability drain NODE_ID
# On the node: docker swarm leave
docker node rm NODE_ID
```

## Promoting/Demoting
```bash
docker node promote NODE_ID    # Worker to Manager
docker node demote NODE_ID     # Manager to Worker
```
Always maintain odd number of managers (3 or 5).

## Draining for Maintenance
```bash
docker node update --availability drain swarm-worker1
# Perform maintenance...
docker node update --availability active swarm-worker1
```

## Quorum Recovery
```bash
docker swarm init --force-new-cluster --advertise-addr MANAGER_IP
```

## Backup & Restore
```bash
# Backup
sudo systemctl stop docker
sudo cp -r /var/lib/docker/swarm /backup/swarm-$(date +%Y%m%d)
sudo systemctl start docker

# Restore
sudo systemctl stop docker
sudo cp -r /backup/swarm-YYYYMMDD /var/lib/docker/swarm
sudo systemctl start docker
docker swarm init --force-new-cluster --advertise-addr IP
```

## Node Labels
```bash
docker node update --label-add type=db swarm-worker1
docker node inspect swarm-worker1 --format '{{json .Spec.Labels}}'
```

Use in compose:
```yaml
placement:
  constraints: [node.labels.type == db]
```
