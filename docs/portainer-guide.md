# Portainer Stack Management Guide (Part 3)

## Installation
```bash
docker volume create portainer_data
docker service create --name portainer \
  --publish 9443:9443 --replicas 1 \
  --constraint 'node.role==manager' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=volume,src=portainer_data,dst=/data \
  portainer/portainer-ce:latest
```

Access: `https://MANAGER_IP:9443`

## Deploying via Portainer UI

1. Log in → select Swarm environment
2. Go to **Stacks** → **Add Stack**
3. Choose **Upload** → select `docker-compose.yml`
4. Add environment variables if needed
5. Click **Deploy the stack**

## Deploying via Portainer API

Use `scripts/portainer-deploy.sh`:
```bash
PORTAINER_URL=https://localhost:9443 \
PORTAINER_USER=admin \
PORTAINER_PASSWORD=yourpassword \
./scripts/portainer-deploy.sh deploy
```

Commands: `deploy`, `list`, `status`

## Best Practices

- **Naming**: Use `env-appname` format (e.g., `prod-webapp`)
- **Secrets**: Use Swarm secrets, not Portainer env vars for passwords
- **Templates**: Save stack as App Template for repeatable deployments
- **RBAC**: Configure role-based access for team members
