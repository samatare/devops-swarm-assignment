# Migration Strategy: Docker Swarm to Kubernetes

## 1. Executive Summary

This document outlines a phased migration plan for moving our microservices application stack from Docker Swarm to Kubernetes. The migration prioritizes zero-downtime transition, risk mitigation through parallel environments, and validation at each phase before proceeding. Our current stack consists of five services (Traefik reverse proxy, nginx frontend, nginx backend API, PostgreSQL database, and Redis cache) running on a 3-node Docker Swarm cluster on AWS EC2 instances.

## 2. Current State Assessment

### Swarm Features in Use and Kubernetes Equivalents

Our Docker Swarm deployment uses several key features that have direct Kubernetes equivalents:

Docker Compose stack files define our service configurations. In Kubernetes, these translate to Helm charts containing Deployment, Service, and Ingress manifests. Our Swarm services running in replicated mode (frontend and backend with 3 replicas each) map directly to Kubernetes Deployments with ReplicaSets. The global mode services (Node Exporter and cAdvisor running on every node) become Kubernetes DaemonSets.

Swarm overlay networks provide multi-tier isolation (public, frontend, backend, monitor). In Kubernetes, this translates to a CNI plugin (Calico or Cilium recommended) combined with NetworkPolicies that explicitly define which pods can communicate with each other. Our current network segmentation where PostgreSQL is isolated on the backend network would be enforced through NetworkPolicies restricting ingress to only pods with the backend label.

Swarm secrets, stored encrypted in the Raft log and mounted as tmpfs files at /run/secrets/, map to Kubernetes Secrets. However, Kubernetes secrets are only base64-encoded by default, not encrypted at rest. We recommend implementing External Secrets Operator to pull credentials from AWS Secrets Manager, providing equivalent or better security than Swarm secrets.

Placement constraints (node.labels.type == db for PostgreSQL, node.role == worker for backend) translate to Kubernetes nodeSelector and nodeAffinity rules. Our spread placement preferences become topologySpreadConstraints in Kubernetes, providing even distribution of pods across nodes.

Named volumes for PostgreSQL data persistence require the most significant change. Swarm volumes are node-local, which is why we pin PostgreSQL to a specific node. Kubernetes solves this properly with PersistentVolumes backed by cloud storage (EBS volumes on AWS), allowing StatefulSets to maintain data regardless of which node the pod runs on.

Traefik as our reverse proxy can be migrated directly since Traefik supports both Docker Swarm and Kubernetes providers. We would switch from the Docker provider with swarmMode to the Kubernetes Ingress provider, maintaining the same routing rules.

Our Swarm update configuration (parallelism=2, delay=10s, failure_action=rollback, order=start-first) maps to Kubernetes Deployment strategy with type=RollingUpdate, maxSurge=1, maxUnavailable=0, providing the same zero-downtime guarantee.

## 3. Migration Approach: Phased Migration

We recommend a phased migration over a big-bang approach for several important reasons. First, it allows us to validate each component independently before migrating the next. Second, it provides instant rollback capability at each phase by simply shifting traffic back to the Swarm cluster. Third, it enables the team to learn Kubernetes progressively during the migration rather than requiring full expertise upfront.

### Phase 1: Infrastructure Setup (Weeks 1-2)

Provision a Kubernetes cluster using Amazon EKS. Install the CNI plugin (Calico), Ingress controller (Traefik), cert-manager for TLS, and the monitoring stack (Prometheus Operator). Set up CI/CD pipelines to build and deploy to both Swarm and Kubernetes simultaneously. Deploy the monitoring stack first as it has no user-facing traffic risk.

Deliverables: Working EKS cluster, CI/CD pipeline modifications, monitoring stack operational.

### Phase 2: Stateless Services Migration (Weeks 3-4)

Migrate the frontend and backend services as Kubernetes Deployments. Configure Ingress rules replicating the Traefik path-based routing. Run both Swarm and Kubernetes behind an AWS Application Load Balancer. Gradually shift traffic using weighted target groups: 10 percent to Kubernetes initially, then 25 percent, 50 percent, and finally 100 percent over two weeks. Monitor error rates, response times, and resource utilization at each increment.

Validation criteria: Error rate below 0.1 percent, p95 response time within 10 percent of Swarm baseline, all health checks passing.

### Phase 3: Stateful Services Migration (Weeks 5-6)

This is the highest-risk phase. Migrate Redis first since its data is ephemeral cache. For PostgreSQL, we recommend migrating to AWS RDS rather than a Kubernetes StatefulSet. This eliminates the operational burden of managing database backups, replication, and failover within Kubernetes. Migration steps: create RDS instance, set up logical replication from Swarm PostgreSQL, validate data integrity with checksums and row counts, cut over by updating the backend configuration to point to RDS.

If RDS is not an option, deploy PostgreSQL as a StatefulSet with a PersistentVolumeClaim backed by EBS. Use pg_dump for initial data migration and verify with comparison queries.

### Phase 4: Decommission Swarm (Weeks 7-8)

After all services run successfully on Kubernetes for at least one week with zero issues, decommission the Swarm cluster. Archive all Swarm configuration files for reference. Update documentation and runbooks. Remove the EC2 instances. Update DNS records and remove the ALB weighted routing.

## 4. Tooling

Kompose can auto-convert docker-compose.yml to Kubernetes manifests but produces verbose output requiring significant cleanup. We recommend manual conversion using Helm charts, which provides parameterized templates, environment-specific values files, and built-in rollback via helm rollback. The Helm chart for our stack is provided in migration/helm-chart/ with templates for all services.

For GitOps-based continuous deployment, we recommend ArgoCD watching a Git repository containing the Helm charts. This replaces Portainer role in the deployment workflow and provides a full audit trail of every deployment.

## 5. Testing Strategy

Unit tests validate each Kubernetes manifest with kubectl dry-run and kubeconform for schema compliance. Integration tests deploy to a staging Kubernetes cluster and run end-to-end smoke tests against all API endpoints. Load tests use k6 to compare performance metrics between Swarm and Kubernetes deployments using identical traffic patterns. Chaos tests use chaos-mesh to simulate node failures and pod evictions, verifying self-healing behavior matches Swarm capabilities. Data integrity verification after database migration uses checksums, row counts, and sample query comparisons.

## 6. Rollback Plan

Each phase has an independent rollback path. Phase 1: Delete the EKS cluster and Swarm is unaffected. Phase 2: Shift ALB weight back to 100 percent Swarm traffic. Phase 3: Repoint backend to Swarm PostgreSQL and restore from pre-migration backup if needed. Phase 4: Re-deploy Swarm from archived configuration files.

## 7. Risk Assessment

The highest risk is data loss during PostgreSQL migration. Mitigation includes full backup before migration, logical replication for real-time sync, and validation queries before cutover. Medium risk is performance regression on Kubernetes, mitigated by load testing before traffic shift and gradual percentage-based cutover. Medium risk is team unfamiliarity with Kubernetes, mitigated by training sessions during Phase 1 and pair programming. Low risk is networking differences causing connectivity issues, mitigated by parallel environments allowing instant rollback.

## 8. Timeline Summary

Weeks 1-2: Infrastructure setup with low risk. Weeks 3-4: Stateless migration with gradual traffic shift at medium risk. Weeks 5-6: Stateful migration including database at high risk. Weeks 7-8: Decommission Swarm and finalize documentation at low risk. Total estimated duration is 8 weeks with buffer for unexpected issues.
