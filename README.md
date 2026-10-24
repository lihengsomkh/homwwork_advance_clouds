# End-to-End Automated CI/CD Pipeline on AWS Docker Swarm with Jenkins & Amazon ECR

This repository provides an enterprise-ready, automated CI/CD pipeline implementation deploying a lightweight, production-grade microservice to an AWS EC2 Docker Swarm cluster via Jenkins and Amazon Elastic Container Registry (ECR).

---

## 1. Architecture Overview

```
                      +-------------------+
                      |   Developer Git   |
                      |    Push / PR      |
                      +---------+---------+
                                |
                                v
                      +-------------------+
                      |  GitHub Repository|
                      +---------+---------+
                                |  Webhook / SCM Poll
                                v
               +----------------------------------+
               |     Jenkins Controller / Agent   |
               |  (AWS EC2 with IAM Instance Role)|
               +----------------+-----------------+
                                |
           +--------------------+--------------------+
           |                                         |
           v [Build, Tag & Push]                     v [SSH Stack Deploy]
+----------------------+                  +-----------------------+
|  Amazon ECR Registry |                  |  AWS EC2 Swarm Manager|
| (Private Repository) |                  | (Ingress / Orchestrator)
+----------+-----------+                  +-----------+-----------+
           |                                          |
           | Registry Auth Pull                       | Overlay Network
           +--------------------+---------------------+
                                |
             +------------------+------------------+
             |                                     |
             v                                     v
+------------------------+             +------------------------+
|  AWS EC2 Worker Node 1 |             |  AWS EC2 Worker Node 2 |
|   [web-api replica 1]  |             |   [web-api replica 2]  |
|   [web-api replica 3]  |             |                        |
+------------------------+             +------------------------+
```

---

## 2. Repository Structure

```
├── .dockerignore                 # Excludes build artifacts, secrets, and git metadata
├── .gitignore                    # Git exclusions for dependencies, env files, keys
├── Dockerfile                    # Multi-stage, lean, non-root Alpine Node.js image
├── Jenkinsfile                   # Declarative pipeline-as-code for build, ECR, and Swarm deploy
├── README.md                     # Technical documentation & operations guide
├── RELEASING.md                  # Release operations, Semantic Versioning & Zero-Rebuild Rollback runbook
├── REPORT.md                     # Academic coursework report & rubric compliance matrix
├── docker-stack.yml              # Swarm multi-replica service definition with rolling update policy
├── package.json                  # Node.js application manifest & dependencies
├── server.js                     # Production Express microservice with /health and graceful shutdown
└── scripts/
    ├── verify-cluster.sh         # Linux audit script for Swarm manager/worker status
    ├── verify-security-groups.sh # AWS Security Group & network port verification
    ├── verify-rolling-update.sh  # Zero-downtime HTTP prober during service update
    ├── verify-rolling-update.ps1 # Cross-platform PowerShell prober for Windows
    ├── trigger-jenkins-build.ps1 # Automation helper to trigger Jenkins parameterized builds
    └── wait-jenkins-build.ps1    # Automation helper to monitor Jenkins build runs
```

---

## 3. Microservice Specifications

- **Runtime**: Node.js 20 on Alpine Linux.
- **Security**: Runs under unprivileged non-root user `node` (`uid=1000`, `gid=1000`).
- **Signal Forwarding**: Utilizes `dumb-init` for proper `SIGTERM`/`SIGINT` handling during Swarm rolling updates.
- **Key Endpoints**:
  - `GET /` — Service status, environment, version, container hostname, and platform metrics.
  - `GET /health` — Liveness & readiness probe for Docker Swarm routing and load balancers.
  - `GET /api/v1/info` — Detailed node and network diagnostic telemetry.

---

## 4. Local Build & Smoke Testing

To test the container locally before deploying to AWS:

```bash
# 1. Build the local Docker image
docker build -t cloud-microservice:local .

# 2. Run the container locally
docker run -d --name test-app -p 3000:3000 cloud-microservice:local

# 3. Test the application endpoint
curl http://localhost:3000/

# 4. Verify health check
curl http://localhost:3000/health

# 5. Confirm non-root execution
docker exec test-app whoami
# Expected output: node

# 6. Cleanup
docker stop test-app && docker rm test-app
```

---

## 5. Docker Swarm Stack Configuration (`docker-stack.yml`)

The stack is configured for high availability and zero downtime:
- **Replicas**: 3 concurrent tasks balanced across Swarm nodes.
- **Rolling Update Strategy**:
  - `parallelism: 1` — Replaces one container at a time.
  - `delay: 10s` — Buffer between updating subsequent replicas.
  - `order: start-first` — Starts and health-checks the new replica *before* terminating the old one, ensuring zero dropped requests.
  - `failure_action: rollback` — Automatically rolls back if an update fails healthchecks.
- **Resource Constraints**: Capped CPU and Memory reservations to prevent noisy-neighbor starvation.
- **Overlay Network**: Isolated VXLAN network (`swarm-overlay-net`) with ingress routing mesh.

---

## 6. Jenkins Declarative Pipeline Stages

The `Jenkinsfile` executes the following declarative stages:
1. **Checkout SCM**: Clones latest commit and sets dynamic tag `${BUILD_NUMBER}-${GIT_COMMIT}`.
2. **Code Lint & Unit Verification**: Confirms file integrity and validates manifests.
3. **Build & Tag Docker Image**: Builds non-root image and tags it with both the immutable build SHA tag and `latest`.
4. **Authenticate & Push to Amazon ECR**:
   - Generates authentication token via `aws ecr get-login-password`.
   - Pushes both tags to the private Amazon ECR repository.
5. **Deploy to Docker Swarm via SSH**:
   - Copies `docker-stack.yml` to the Swarm Manager host over SSH.
   - Executes `docker stack deploy --with-registry-auth -c docker-stack.yml <stack_name>`.
   - Verifies convergence via `docker stack services` and `docker service ps`.
6. **Post Actions**: Cleans up local build images on the Jenkins agent to prevent disk exhaustion.

---

## 7. Cluster & Security Group Configuration

### Required Inbound Port Rules for Docker Swarm on AWS EC2:

| Port / Protocol | Source | Purpose |
| :--- | :--- | :--- |
| **22 / TCP** | Jenkins EC2 / Bastion | SSH management and deployment |
| **80 / TCP** | `0.0.0.0/0` (Internet) | Public web traffic into Swarm routing mesh |
| **2377 / TCP** | Swarm Security Group | Cluster management communications (Manager node) |
| **7946 / TCP + UDP** | Swarm Security Group | Node discovery & gossip control plane |
| **4789 / UDP** | Swarm Security Group | Overlay network VXLAN data plane |

> [!IMPORTANT]
> Ports `2377`, `7946`, and `4789` MUST be restricted to the security group shared by the Swarm Manager and Worker EC2 instances, and NEVER exposed to the public internet (`0.0.0.0/0`).

---

## 8. Verification & Audit Scripts

Run these scripts from the manager or local machine to audit cluster health:

```bash
# Verify Swarm nodes, active stacks, and replica distribution
chmod +x ./scripts/*.sh
./scripts/verify-cluster.sh cloud-microservice-stack

# Verify AWS Security Group rules
./scripts/verify-security-groups.sh <sg-xxxxxxxxx>

# Verify Zero-Downtime Rolling Update during deployment (Linux/macOS)
./scripts/verify-rolling-update.sh http://<SWARM_MANAGER_OR_ALB_IP> 60 0.5

# Windows PowerShell alternative
powershell -ExecutionPolicy Bypass -File ./scripts/verify-rolling-update.ps1 -TargetUrl http://<SWARM_MANAGER_OR_ALB_IP> -TotalProbes 30
```

---

## 9. Release Management, Semantic Versioning & Zero-Rebuild Rollbacks (Homework 3)

For detailed operational procedures, see [RELEASING.md](file:///d:/MBA_IT/advance%20clouds/homework2/RELEASING.md).

### 9.1 Parameterized Pipeline Overview
The Jenkins pipeline supports two operational modes controlled by the `ACTION` parameter:

```groovy
parameters {
    choice(name: 'ACTION', choices: ['deploy', 'rollback'], 
           description: 'deploy: compile, tag, push & deploy | rollback: zero-rebuild immediate recovery')
    string(name: 'VERSION', defaultValue: 'v1.0.0', 
           description: 'Target Semantic Version (vMAJOR.MINOR.PATCH)')
}
```

### 9.2 Release Operations (Deploy Mode)
1. Commit code and tag the release:
   ```bash
   git tag -a v1.2.0 -m "Release v1.2.0"
   git push origin v1.2.0
   ```
2. Trigger the pipeline via Jenkins UI or CLI with `ACTION=deploy`, `VERSION=v1.2.0`.
3. Pipeline builds the Docker image, tags it with `v1.2.0`, validates image presence, and executes a start-first zero-downtime rolling update on Docker Swarm.

### 9.3 Emergency Zero-Rebuild Rollback (Rollback Mode)
When a critical defect is identified in production:
1. Open Jenkins: `http://localhost:8080/job/cloud-microservice-pipeline/`
2. Select **Build with Parameters**:
   - `ACTION`: `rollback`
   - `VERSION`: `v1.0.0` (target stable release)
3. **Behavior**:
   - Stages 3 (Build) and 4 (Push) are **automatically skipped**.
   - Stage 5 (Rollback Guard) verifies that image tag `v1.0.0` exists in the registry.
   - Stage 6 immediately rolls out the verified pre-built image to Swarm in ~20 seconds.
   - Zero downtime, zero code rebuilds, 100% deterministic recovery!

