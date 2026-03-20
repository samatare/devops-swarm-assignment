# Docker Swarm Production Deployment – Senior DevOps Assignment

## Architecture Overview

This project deploys a microservices application stack on a 3-node Docker Swarm cluster (AWS EC2):
```
                    INTERNET
                       |
                    :80 HTTP
                       |
                 ┌─────────────┐
                 │   Traefik   │  (Manager Node)
                 │  v2.11 LB   │
                 └──────┬──────┘
                   /         \
           PathPrefix(/)   PathPrefix(/api)
                /               \
    ┌───────────────┐   ┌───────────────┐
    │   Frontend    │   │    Backend    │
    │  nginx:alpine │   │  nginx:alpine │
    │  3 replicas   │   │  3 replicas   │
    └───────────────┘   └───────┬───────┘
                                |
                    ┌───────────┴───────────┐
                    │                       │
             ┌──────────┐           ┌───────────┐
             │ PostgreSQL│           │   Redis   │
             │   15-alp  │           │  7-alpine │
             │  pinned   │           │  1 replica│
             └──────────┘           └───────────┘
```

### Nodes
- **swarm-manager**: Traefik, Prometheus, Grafana, Portainer
- **swarm-worker1**: Frontend, Backend, PostgreSQL (pinned via label `type=db`)
- **swarm-worker2**: Frontend, Backend, Redis

### Key Design Decisions
- **Traefik v2.11** over Nginx: native Swarm service discovery via labels, zero manual config
- **nginx:alpine** as placeholder images: real HTTP servers that pass health checks (replace with custom images in production)
- **`order: start-first`** for zero-downtime rolling updates
- **PostgreSQL pinned** to labeled node because Swarm volumes are node-local
- **Multi-tier networks**: public, frontend, backend (database isolated from public)
- **Swarm secrets** mounted as tmpfs files (not environment variables)
- **HTTP only** for demo (Let's Encrypt requires a real domain name, not raw IPs)

## How to Deploy

### Prerequisites
- 3 EC2 instances (t3.small, Ubuntu 22.04) with Docker installed
- Docker Swarm initialized (1 manager + 2 workers)
- Node labels: `docker node update --label-add type=db swarm-worker1`

### Deploy Steps
```bash
# 1. Create secrets
chmod +x scripts/*.sh
./scripts/create-secrets.sh

# 2. Create external network
docker network create --driver overlay --opt encrypted=true monitor

# 3. Deploy main stack
docker stack deploy -c docker-compose.yml app

# 4. Deploy monitoring
docker stack deploy -c docker-compose.monitoring.yml monitoring

# 5. Deploy Portainer
docker volume create portainer_data
docker service create --name portainer --publish 9443:9443 --replicas 1 \
  --constraint 'node.role==manager' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=volume,src=portainer_data,dst=/data \
  portainer/portainer-ce:latest

# 6. Verify
docker stack services app
curl http://localhost/
```

### Test Externally
```
curl http://MANAGER_PUBLIC_IP/       # Frontend
curl http://MANAGER_PUBLIC_IP/api    # Backend
https://MANAGER_PUBLIC_IP:9443       # Portainer UI
```

## Swarm-Specific Considerations

- **Docker Engine 29.x compatibility**: Traefik v3.x has API version mismatch with Docker 29. We use Traefik v2.11 with `DOCKER_API_VERSION=1.45`.
- **Network naming**: Swarm prefixes network names with stack name. Traefik config uses `app_public` (not just `public`).
- **Volume persistence**: Swarm volumes are node-local. Stateful services must be pinned via placement constraints.
- **CRLF line endings**: Scripts created on Windows must be converted with `sed -i 's/\r$//' scripts/*.sh`.

## Migration Strategy

See `migration/migration-strategy.md` for the comprehensive Swarm-to-Kubernetes migration plan using a phased approach over 8 weeks.

## Assumptions

- Raw IP used for testing (no domain name available for Let's Encrypt SSL)
- `nginx:alpine` used as placeholder for frontend/backend (real images built via Dockerfiles in `dockerfiles/`)
- Single availability zone deployment (production would use multi-AZ)
- t3.small instances with 2GB RAM constrain replica counts
