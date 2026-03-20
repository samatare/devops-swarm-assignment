# BONUS: Chaos Engineering — Simulating Node Failures

## Test 1: Kill a Worker Node

Simulate swarm-worker2 going down:

```bash
# Drain the node (simulates failure)
docker node update --availability drain swarm-worker2

# Watch services redistribute
watch docker service ps app_backend

# Expected: All backend replicas move to swarm-worker1
# Frontend replicas also redistribute

# Restore
docker node update --availability active swarm-worker2

```

## Test 2: Kill Backend Containers
worker 1
worker 2 
172.31.36.184
172.31.44.44
```bash
# SSH to a worker and kill all backend containers
ssh 172.31.36.184 "docker kill \$(docker ps -q -f name=app_backend)"

# Watch Swarm auto-heal
watch docker service ps app_backend --filter desired-state=running

# Expected: Swarm detects missing tasks and schedules replacements
```

## Test 3: Simulate Network Partition

```bash
# On worker2, block traffic to manager (simulates network split)
ssh swarm-worker2 "sudo iptables -A INPUT -s MANAGER_PRIVATE_IP -j DROP"

# Check node status from manager
docker node ls
# worker2 should show "Down" after ~30 seconds

# Restore
ssh swarm-worker2 "sudo iptables -D INPUT -s MANAGER_PRIVATE_IP -j DROP"
```

## Results

Swarm self-healing demonstrated:
- Tasks automatically rescheduled when node is drained
- Killed containers are replaced within seconds
- Partitioned nodes detected within 30 seconds
