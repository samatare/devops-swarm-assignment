# BONUS: Cost Optimization — Swarm vs Kubernetes

## Current Swarm Costs (AWS)

| Resource | Spec | Monthly Cost |
|----------|------|-------------|
| 3x EC2 t3.small | 2 vCPU, 2GB RAM | ~$45/month |
| 3x 20GB EBS gp3 | SSD storage | ~$5/month |
| Data transfer | Intra-AZ free, out ~$0.09/GB | ~$5/month |
| **Total** | | **~$55/month** |

## Optimization Strategies

### 1. Use Spot Instances for Workers (-60%)
Worker nodes are stateless — safe for spot instances.

```bash
aws ec2 run-instances --instance-market-options '{"MarketType":"spot"}'
```
Savings: $30/month → $12/month for 2 workers

### 2. Right-size Instances
Monitor actual usage via Grafana. If CPU < 30% consistently, downgrade:
- t3.small (2 vCPU, 2GB) → t3.micro (2 vCPU, 1GB) saves 50%

### 3. Reserved Instances for Manager (-40%)
Manager runs 24/7 — commit to 1-year reserved instance.

### 4. Swarm vs Kubernetes Cost Comparison

| Factor | Docker Swarm | Kubernetes (EKS) |
|--------|-------------|------------------|
| Control plane | Free (runs on manager) | $72/month (EKS fee) |
| Min nodes | 1 manager + 2 workers | 2 workers (control plane managed) |
| Learning curve | Lower | Higher |
| Ecosystem | Limited | Extensive (Helm, operators, etc.) |
| **Estimated monthly** | **$55** | **$127** |

Swarm is ~57% cheaper for small deployments due to no control plane fee.
