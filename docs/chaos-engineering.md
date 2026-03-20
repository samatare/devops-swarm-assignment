# BONUS: Chaos Engineering - Simulating Node Failures

## Test 1: Drain a Worker Node

Simulate swarm-worker2 going down by draining it:

    docker node update --availability drain swarm-worker2

Watch services redistribute to other nodes:

    docker service ps app_backend --filter desired-state=running

Expected: All backend replicas move to swarm-worker1.

Restore the node:

    docker node update --availability active swarm-worker2

## Test 2: Kill Backend Containers on a Worker

Find which worker has backend containers:

    docker service ps app_backend --format "table {{.Name}}\t{{.Node}}" --filter desired-state=running

SSH to that worker and kill the containers:

    ssh -i ~/.ssh/swarm-key ubuntu@WORKER_PRIVATE_IP "docker kill \$(docker ps -q -f name=app_backend)"

Watch Swarm auto-heal (new containers replace killed ones within seconds):

    watch docker service ps app_backend --filter desired-state=running

## Test 3: Verify Self-Healing

After killing containers or draining nodes:

    docker stack services app

Expected: All services return to full replica count (3/3, 1/1) automatically.

## Results

- Tasks automatically rescheduled when node is drained
- Killed containers replaced within 10-15 seconds
- No manual intervention needed - Swarm self-heals
