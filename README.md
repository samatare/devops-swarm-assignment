# Docker Swarm Production Deployment — Senior DevOps Assignment

## Architecture Overview

This project deploys a production-ready microservices application on a 3-node Docker Swarm cluster (AWS EC2 t3.small instances).
```
                         INTERNET
                            |
                         :80 HTTP
                            |
                    ┌───────────────┐
                    │   Traefik     │  (swarm-manager)
                    │   v2.11 LB   │
                    └───────┬───────┘
                      /           \
              PathPrefix(/)    PathPrefix(/api)
                   /                 \
       ┌────────────────┐   ┌────────────────┐
       │   Frontend     │   │    Backend     │
       │  nginx:alpine  │   │  nginx:alpine  │
       │   3 replicas   │   │   3 replicas   │
       └────────────────┘   └───────┬────────┘
                                    |
                        ┌───────────┴───────────┐
                        │                       │
                 ┌──────────┐           ┌───────────┐
                 │PostgreSQL│           │   Redis   │
                 │ 15-alpine│           │ 7-alpine  │
                 │  pinned  │           │ 1 replica │
                 └──────────┘           └───────────┘
```

### Node Layout
| Node | Role | Services Running |
|------|------|-----------------|
| swarm-manager | Manager + Leader | Traefik, Prometheus, Grafana, Portainer, AlertManager |
| swarm-worker1 | Worker | Frontend, Backend, PostgreSQL (pinned via `type=db` label) |
| swarm-worker2 | Worker | Frontend, Backend, Redis |

### Network Architecture
| Network | Purpose | Services |
|---------|---------|----------|
| app_public | Ingress — Traefik routes external traffic | Traefik, Frontend, Backend |
| app_frontend | Frontend ↔ Backend communication | Frontend, Backend |
| app_backend | Backend ↔ Database/Cache (isolated) | Backend, PostgreSQL, Redis |
| monitor | Observability stack | Prometheus, Grafana, Node Exporter, cAdvisor |

**Key isolation:** PostgreSQL is ONLY on the backend network. Even if the frontend is compromised, the attacker cannot reach the database directly.

---

## Design Decisions & Trade-offs

### Why Traefik v2.11 over Nginx?
- **Native Swarm integration:** Traefik auto-discovers services via Docker labels — no manual upstream configuration needed when services scale or redeploy.
- **Why not v3.x?** Docker Engine 29.x dropped support for API versions below 1.40. Traefik v3.x defaults to API 1.24 and ignores the `DOCKER_API_VERSION` environment variable. Traefik v2.11 correctly reads `DOCKER_API_VERSION=1.45`, solving the compatibility issue.
- **Trade-off:** Traefik requires Docker socket access (mounted read-only as a security measure). Nginx would not need socket access but requires manual upstream management.

### Why nginx:alpine as Placeholder Images?
- The assignment allows choosing your own stack. We use `nginx:alpine` as placeholder images that actually serve HTTP traffic and pass health checks, enabling us to test the full Swarm orchestration (replicas, rolling updates, health checks, Traefik routing) without building custom application images first.
- **When ready:** Replace with your custom images via `docker service update --image ghcr.io/yourorg/backend:v1 app_backend`
- Dockerfiles for building real images are provided in `dockerfiles/`.

### Why `order: start-first`?
- Starts the new container BEFORE stopping the old one, ensuring at least N healthy replicas at all times during updates.
- **Trade-off:** Briefly runs N+1 containers (slightly higher resource usage during deploys). Acceptable for zero-downtime guarantee.

### Why Pin PostgreSQL to a Labeled Node?
- Docker Swarm volumes are node-local. If PostgreSQL is rescheduled to a different node, it starts with an empty volume = **data loss**.
- The constraint `node.labels.type == db` ensures Postgres always runs on `swarm-worker1`.
- **Trade-off:** Single point of failure for the database. In production, use AWS RDS or implement Patroni for HA PostgreSQL.

### Why Swarm Secrets over Environment Variables?
- Environment variables are visible in `docker inspect`, process listings (`/proc/*/environ`), and crash dumps.
- Swarm secrets are stored encrypted in the Raft log and mounted as in-memory tmpfs files at `/run/secrets/` — they never touch disk inside the container.

### Why HTTP Instead of HTTPS?
- Let's Encrypt requires a real domain name to issue certificates. Our demo uses raw EC2 public IPs.
- The compose file is ready for HTTPS — add the `websecure` entrypoint and Let's Encrypt resolver when a domain is available.

---

## How to Deploy and Test

### Prerequisites
- 3 EC2 instances (t3.small, Ubuntu 22.04) with Docker Engine installed
- Docker Swarm initialized: 1 manager + 2 workers
- Node labeled: `docker node update --label-add type=db swarm-worker1`
- Scripts converted from Windows line endings: `sed -i 's/\r$//' scripts/*.sh`

### Step-by-Step Deployment
```bash
# 1. Create Swarm secrets
chmod +x scripts/*.sh
./scripts/create-secrets.sh

# 2. Create external monitoring network
docker network create --driver overlay --opt encrypted=true monitor

# 3. Deploy main application stack
docker stack deploy -c docker-compose.yml app
sleep 30

# 4. Verify all services are running
docker stack services app
# Expected: frontend 3/3, backend 3/3, postgres 1/1, redis 1/1, traefik 1/1

# 5. Deploy monitoring stack
docker stack deploy -c docker-compose.monitoring.yml monitoring

# 6. Deploy Portainer
docker volume create portainer_data
docker service create --name portainer --publish 9443:9443 --replicas 1 \
  --constraint 'node.role==manager' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=volume,src=portainer_data,dst=/data \
  portainer/portainer-ce:latest
```

### Testing
```bash
# From the manager node
curl http://localhost/        # Frontend — returns nginx welcome page
curl http://localhost/api     # Backend — returns nginx 404 (placeholder)

# From outside (replace with your manager's public IP)
curl http://MANAGER_PUBLIC_IP/
curl http://MANAGER_PUBLIC_IP/api

# Portainer UI
# Open https://MANAGER_PUBLIC_IP:9443 in browser

# Traefik Dashboard
# Open http://MANAGER_PUBLIC_IP:8080 in browser

# Verify service distribution
docker service ps app_backend --format "table {{.Name}}\t{{.Node}}"
# Should show tasks on both worker1 and worker2
```

### Rolling Update Test
```bash
# Successful update
docker service update --image nginx:1.25-alpine app_backend
# Auto-rollback on failure
docker service update --image ghcr.io/fake/broken:v1 app_backend
# Manual rollback
docker service rollback app_backend
```

---

## Swarm-Specific Considerations

| Consideration | Detail |
|--------------|--------|
| Docker Engine 29 compatibility | Traefik v3.x incompatible — use v2.11 with `DOCKER_API_VERSION=1.45` |
| Network naming | Swarm prefixes stack name: `public` becomes `app_public`. Traefik config must use full name. |
| Volume persistence | Node-local only. Pin stateful services via `node.labels.type == db` constraint. |
| CRLF line endings | Scripts from Windows need `sed -i 's/\r$//' scripts/*.sh` before running on Linux. |
| Service discovery | Swarm built-in DNS resolves service names (e.g., `postgres`, `redis`) to VIPs within overlay networks. |
| Health checks | Must use tools available in the image (`wget` in nginx:alpine, not `curl`). |
| Rollback behavior | `docker service rollback` requires at least one prior `docker service update`. |

---

## Migration Strategy Rationale

See `migration/migration-strategy.md` for the full document.

**Summary:** We recommend a **phased migration** over 8 weeks rather than big-bang because:

1. **Lower risk** — validate each component before migrating the next
2. **Instant rollback** — shift load balancer back to Swarm if K8s has issues
3. **Team learning** — staff learns Kubernetes progressively during migration
4. **Business continuity** — production traffic always has a working target

**Key mapping:** Swarm services → K8s Deployments, Swarm secrets → K8s Secrets + External Secrets Operator, overlay networks → CNI + NetworkPolicies, placement constraints → nodeSelector/affinity, named volumes → PersistentVolumeClaims.

**Biggest risk:** Stateful service migration (PostgreSQL). Mitigation: use AWS RDS as the migration target instead of self-hosted K8s StatefulSet.

---

## Directory Structure
```
devops-swarm-assignment/
├── README.md                              # This file
├── docker-compose.yml                     # Main Swarm stack (Part 1)
├── docker-compose.monitoring.yml          # Monitoring stack (Part 4)
├── app/
│   ├── frontend/server.js                 # Simple frontend app
│   └── backend/server.js                  # Simple backend API
├── dockerfiles/
│   ├── frontend.Dockerfile                # Optimized multi-stage build (Part 7.2)
│   └── backend.Dockerfile                 # Optimized multi-stage build (Part 7.2)
├── scripts/
│   ├── create-secrets.sh                  # Create Swarm secrets (Part 1.3)
│   ├── rotate-secrets.sh                  # Rotate secrets without downtime (Part 1.3)
│   └── portainer-deploy.sh               # Portainer API automation (Part 3.2)
├── monitoring/
│   ├── prometheus/prometheus.yml           # Prometheus scrape config (Part 4.1)
│   ├── prometheus/alert-rules.yml         # Alert rules (Part 4.3)
│   ├── grafana/dashboard.json             # Custom Grafana dashboard (Part 4.1)
│   └── alertmanager/alertmanager.yml      # AlertManager config (Part 4.3)
├── .github/workflows/deploy.yml           # CI/CD pipeline (Part 7.1)
├── ci-cd/.github/workflows/deploy.yml     # CI/CD pipeline copy
├── migration/
│   ├── migration-strategy.md              # Swarm to K8s plan (Part 6.1)
│   └── helm-chart/                        # Helm chart conversion (Part 6.2)
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── frontend-deployment.yaml
│           ├── backend-deployment.yaml
│           ├── postgres-statefulset.yaml
│           ├── redis-deployment.yaml
│           ├── ingress.yaml
│           ├── secrets.yaml
│           ├── configmaps.yaml
│           └── services.yaml
└── docs/
    ├── troubleshooting.md                 # Operations & troubleshooting (Part 5)
    ├── swarm-operations.md                # Cluster management runbook (Part 5.3)
    ├── portainer-guide.md                 # Portainer setup guide (Part 3.1)
    ├── security-checklist.md              # Security hardening (Part 8.1)
    └── production-readiness.md            # Production checklist (Part 8.2)
```

---

## Assumptions

1. **Raw IP for testing** — no domain name available for Let's Encrypt SSL certificates
2. **nginx:alpine as placeholders** — real application images built via Dockerfiles in `dockerfiles/`
3. **Single availability zone** — all 3 EC2 instances in same AZ (production would use multi-AZ)
4. **t3.small instances** — 2 vCPU, 2GB RAM constrains replica counts and resource limits
5. **Traefik v2.11** — chosen over v3.x due to Docker Engine 29 API compatibility issue
6. **HTTP only for demo** — HTTPS config ready to enable when domain is available
7. **Portainer for Swarm management** — provides UI and API for stack deployment
