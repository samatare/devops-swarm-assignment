# BONUS: Cost Optimization - Swarm vs Kubernetes

## Current Swarm Costs (AWS)

| Resource | Spec | Monthly Cost |
|----------|------|-------------|
| 3x EC2 t3.small | 2 vCPU, 2GB RAM | ~$45/month |
| 3x 20GB EBS gp3 | SSD storage | ~$5/month |
| Data transfer | Intra-AZ free | ~$5/month |
| Total | | ~$55/month |

## Optimization Strategies

1. Use Spot Instances for Workers (-60%) - workers are stateless, safe for spot
2. Right-size Instances - if CPU < 30%, downgrade t3.small to t3.micro (saves 50%)
3. Reserved Instances for Manager (-40%) - runs 24/7, commit to 1-year

## Swarm vs Kubernetes Cost Comparison

| Factor | Docker Swarm | Kubernetes (EKS) |
|--------|-------------|------------------|
| Control plane | Free (on manager) | $72/month (EKS fee) |
| Min nodes | 1 manager + 2 workers | 2 workers |
| Learning curve | Lower | Higher |
| Ecosystem | Limited | Extensive |
| Estimated monthly | $55 | $127 |

Swarm is ~57% cheaper for small deployments due to no control plane fee.
