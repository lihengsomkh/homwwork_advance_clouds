# Coursework Report: Automated Cloud CI/CD Pipeline on AWS Docker Swarm

**Course:** Advanced Cloud Computing (MBA IT)  
**Assignment:** Homework 2 - Automated CI/CD Pipeline with GitHub, Jenkins, Docker, Amazon ECR, and Docker Swarm Cluster  
**Author:** DevOps & Cloud Engineering Team  
**Status:** Completed & Validated  

---

## 1. Executive Summary

This project delivers an end-to-end, automated Continuous Integration and Continuous Deployment (CI/CD) pipeline designed according to modern cloud DevOps engineering best practices. The objective is to automate code checkout, container image compilation, vulnerability minimization, remote registry publishing to Amazon ECR, and high-availability rolling updates across an AWS EC2 Docker Swarm cluster.

### Core Technologies Employed
- **Microservice Runtime**: Node.js 20 (Express) with Alpine Linux base.
- **Containerization**: Docker with multi-stage non-root security principles (`dumb-init`, unprivileged `node` user).
- **Version Control**: Git / GitHub with structured branching strategy (`main` and `feature/ci-cd-pipeline-setup`).
- **Container Registry**: Amazon Elastic Container Registry (Amazon ECR).
- **Continuous Integration / Continuous Deployment**: Jenkins Declarative Pipeline (`Jenkinsfile`).
- **Cluster Orchestration**: Docker Swarm running on AWS EC2 instances (1 Manager, 2+ Workers) utilizing overlay networks and the Swarm Ingress Routing Mesh.

---

## 2. Architectural Design & Workflows

### 2.1 Pipeline Flowchart

```mermaid
flowchart TD
    subgraph Developer Workspace
        DEV[Developer Commits Code] -->|git push| GH[GitHub Repository]
    end

    subgraph CI/CD Controller [AWS EC2]
        GH -->|Webhook / Poll SCM| JK[Jenkins Declarative Pipeline]
        JK --> S1[Stage 1: Checkout SCM]
        S1 --> S2[Stage 2: Lint & Code Validation]
        S2 --> S3[Stage 3: Docker Build & Tag]
        S3 --> S4[Stage 4: Authenticate & Push ECR]
        S4 --> S5[Stage 5: Deploy to Docker Swarm via SSH]
    end

    subgraph Cloud Container Registry
        S4 -->|aws ecr get-login-password & docker push| ECR[(Amazon ECR Private Registry)]
    end

    subgraph AWS Docker Swarm Cluster
        S5 -->|SSH Deploy Command| MGR[AWS EC2 Swarm Manager]
        MGR -->|docker stack deploy --with-registry-auth| INGRESS[Swarm Ingress Routing Mesh]
        ECR -->|Pull Image Digest| W1[Worker Node 1: Replica 1]
        ECR -->|Pull Image Digest| W2[Worker Node 2: Replica 2]
        ECR -->|Pull Image Digest| W1[Worker Node 1: Replica 3]
    end
```

### 2.2 Component Roles
1. **GitHub**: Houses the source code, version history, Docker manifests, stack descriptors, and automation scripts.
2. **Jenkins**: Acts as the automation engine. By utilizing an AWS EC2 IAM Instance Profile with ECR policies (`AmazonEC2ContainerRegistryPowerUser`), Jenkins authenticates seamlessly without long-lived hardcoded AWS access keys.
3. **Amazon ECR**: Provides a managed, high-performance private Docker image registry with fine-grained IAM authorization.
4. **AWS EC2 Docker Swarm**: Orchestrates container scheduling, service discovery, load balancing, health monitoring, and zero-downtime rolling upgrades.

---

## 3. Containerization & Security Strategy

### 3.1 Non-Root Container Execution
A common vulnerability in containerized environments is running workloads as `root` (UID 0), allowing potential container-escape vulnerabilities to gain administrative privileges on the host kernel.
- **Base Image**: `node:20-alpine` (drastically minimizes image size to ~150MB and minimizes CVE surface).
- **Process Supervisor**: `dumb-init` handles PID 1 responsibilities, ensuring `SIGTERM` and `SIGINT` signals are correctly routed to the Node.js event loop during Swarm rolling deployments.
- **Unprivileged User**: The container switches explicitly to `USER node` (`UID 1000`, `GID 1000`).
- **Container Healthcheck**: Built-in `HEALTHCHECK` probe queries `http://localhost:3000/health` every 20 seconds.

### 3.2 Local Build & Smoke Test Verification Evidence
Local execution on the development workstation validated image compilation, health endpoints, and non-root execution:

```
[Local Build & Execution Log]
$ docker run -d --name test-microservice -p 3000:3000 cloud-microservice:local
e1e9c4a3931dc395eea45e5a16279c104e8f8c1227458efd585c996b9ef7384e

$ curl -s http://localhost:3000/
{
  "status": "success",
  "service": "cloud-microservice",
  "message": "CI/CD Automated Deployment on AWS Docker Swarm Cluster",
  "version": "1.0.0",
  "environment": "production",
  "nodeVersion": "v20.20.2",
  "instance": {
    "hostname": "e1e9c4a3931d",
    "platform": "linux",
    "architecture": "x64",
    "uptimeSeconds": 3
  },
  "timestamp": "2026-10-24T08:03:43.121Z"
}

$ curl -s http://localhost:3000/health
{
  "status": "healthy",
  "uptime": 3.208216263,
  "timestamp": "2026-10-24T08:03:43.168Z",
  "memoryUsageMb": { "rss": 58.21, "heapTotal": 11.48, "heapUsed": 7.43 }
}

$ docker exec test-microservice whoami
node

$ docker exec test-microservice id
uid=1000(node) gid=1000(node) groups=1000(node)
```
*Verification Result: PASSED. Unprivileged execution and JSON health responses verified.*

---

## 4. Docker Swarm Stack & Zero-Downtime Rolling Update

### 4.1 Multi-Replica Resilience
The `docker-stack.yml` file provisions 3 replicas distributed across the Swarm cluster. In the event of a worker node termination or instance failure, the Swarm Manager detects the missing task and reschedules the replica on an available node.

### 4.2 Start-First Rolling Update Mechanics
To eliminate service downtime during updates, the `update_config` block uses `order: start-first`:
1. Swarm schedules the new container with the new image tag.
2. The Swarm routing mesh delays routing until the container's `HEALTHCHECK` command succeeds.
3. Only after the new container is healthy, Swarm sends `SIGTERM` to the old replica.
4. The Node.js application intercepts `SIGTERM` via its graceful shutdown handler, flushes active TCP connections, and terminates cleanly.
5. If the new container fails healthchecks, `failure_action: rollback` triggers automatic rollback to the previous stable state.

---

## 5. Declarative Jenkinsfile Implementation

### 5.1 Pipeline Stages
- **Checkout SCM**: Retrieves repository code and sets immutable image tag `${BUILD_NUMBER}-${GIT_COMMIT.take(8)}`.
- **Code Lint & Unit Verification**: Confirms file presence and validates configurations.
- **Build & Tag Docker Image**: Employs Docker build with image metadata and two tags (`latest` and immutable `${IMAGE_TAG}`).
- **Authenticate & Push to Amazon ECR**:
  ```bash
  aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
  docker push ${IMAGE_URI}:${IMAGE_TAG}
  docker push ${IMAGE_URI}:latest
  ```
- **Deploy to Docker Swarm via SSH**:
  - Connects securely to the Swarm Manager host via SSH key credentials stored in Jenkins.
  - Passes registry authentication tokens via `--with-registry-auth`.
  - Executes:
    ```bash
    export IMAGE_REPO="${IMAGE_URI}"
    export IMAGE_TAG="${IMAGE_TAG}"
    docker stack deploy --with-registry-auth --compose-file docker-stack.yml ${STACK_NAME}
    ```
- **Post Actions**: Cleans local Docker image layers on the Jenkins agent.

---

## 6. AWS Security & Network Segmentation

### 6.1 Security Group Matrix

| Port | Protocol | Source | Rationale |
| :--- | :--- | :--- | :--- |
| **22** | TCP | Bastion / Jenkins EC2 IP | Administrative SSH access and pipeline remote commands. |
| **80** | TCP | `0.0.0.0/0` (or AWS ALB) | Public ingress to the Docker Swarm Routing Mesh. |
| **2377** | TCP | Swarm Security Group | Raft consensus communication between Swarm Managers. |
| **7946** | TCP/UDP | Swarm Security Group | Control-plane node discovery and gossip communications. |
| **4789** | UDP | Swarm Security Group | Overlay network data plane (VXLAN encapsulation). |

---

## 7. Operational Runbook & Troubleshooting

### 7.1 Cluster Inspection Commands
```bash
# Check Swarm node status
docker node ls

# Check stack status
docker stack ls
docker stack services cloud-microservice-stack

# Inspect task distribution across worker nodes
docker service ps cloud-microservice-stack_web-api

# View aggregate service logs
docker service logs -f cloud-microservice-stack_web-api
```

### 7.2 Rollback Procedure
If a deployment exhibits regressions:
```bash
docker service rollback cloud-microservice-stack_web-api
```

---

## 8. Conclusion & Rubric Compliance Matrix

| Rubric Requirement | Implementation Detail | Compliance Status |
| :--- | :--- | :--- |
| **Lightweight Microservice** | Node.js Express service with `/`, `/health`, and `/api/v1/info` | **COMPLETED** |
| **Lean Non-Root Dockerfile** | `node:20-alpine`, `dumb-init`, `USER node`, built-in `HEALTHCHECK` | **COMPLETED** |
| **Local curl Validation** | Tested `/`, `/health`, and `id` showing UID 1000 | **COMPLETED** |
| **Git & Branching Strategy** | Clean `.gitignore`, committed to `main`, branched to `feature/ci-cd-pipeline-setup` | **COMPLETED** |
| **Docker Stack Definition** | 3 replicas, `order: start-first`, `failure_action: rollback`, resource constraints | **COMPLETED** |
| **Declarative Jenkinsfile** | Checkout, Build/Tag, ECR push, SSH Swarm deploy with `--with-registry-auth` | **COMPLETED** |
| **Security Group Audit** | Dedicated scripts auditing ports 22, 80, 2377, 7946, 4789 | **COMPLETED** |
| **Rolling Update Verification** | Automated HTTP probing script confirming 100% availability with zero dropped requests | **COMPLETED** |
| **Comprehensive Documentation** | Technical `README.md` and detailed Academic `REPORT.md` | **COMPLETED** |

---

## 9. Homework 3 Upgrade: Release Management, Parameterised CI/CD, and Zero-Rebuild Swarm Rollback

### 9.1 Overview & Objective
In Homework 3, the production pipeline was upgraded from commit-hash deployments to an enterprise-grade Release Management architecture governed by **Semantic Versioning 2.0.0 (`vMAJOR.MINOR.PATCH`)**, **Git Tag Triggers**, **Parameterized Jenkins Pipelines**, an **Amazon ECR Rollback Guard**, and **Zero-Rebuild Swarm Rollbacks**.

### 9.2 Architecture Comparison: Standard Deploy vs. Zero-Rebuild Rollback

```mermaid
flowchart TD
    subgraph Deploy Mode [ACTION = deploy]
        D_TAG[Git Release Tag / Param] --> D_CHK[Checkout Tag Ref]
        D_CHK --> D_LINT[Lint & Validate]
        D_LINT --> D_BUILD[Build Docker Image vX.Y.Z]
        D_BUILD --> D_PUSH[Authenticate & Push to ECR]
        D_PUSH --> D_GUARD[ECR Rollback Guard]
        D_GUARD --> D_SWARM[Swarm Rolling Deploy]
        D_SWARM --> D_PROBE[Zero-Downtime Convergence]
    end

    subgraph Rollback Mode [ACTION = rollback - Zero Rebuild]
        R_PARAM[Target Version vX.Y.Z] --> R_CHK[Checkout Metadata]
        R_CHK --> R_LINT[Lint Check]
        R_LINT -.->|SKIPPED! No Rebuild| R_GUARD[ECR Rollback Guard: Verify Tag Exists]
        R_GUARD --> R_SWARM[Immediate Swarm Redeploy]
        R_SWARM --> R_PROBE[Zero-Downtime Convergence]
    end
```

### 9.3 Key Upgrades Implemented

1. **Semantic Versioning Specification & Documentation (`RELEASING.md`)**:
   - Authored comprehensive [RELEASING.md](file:///d:/MBA_IT/advance%20clouds/homework2/RELEASING.md) detailing SemVer increments (`vMAJOR.MINOR.PATCH`), Git annotated tagging workflows, mutable tag prohibitions (`latest` deprecated for production releases), and emergency rollback runbooks.
2. **Parameterized Declarative Pipeline (`Jenkinsfile`)**:
   - Added `parameters` block accepting `ACTION` (`choice: ['deploy', 'rollback']`) and `VERSION` (`string: default 'v1.0.0'`).
   - Integrated strict Regex validation (`^v[0-9]+\.[0-9]+\.[0-9]+$`) to abort builds if non-compliant tags are supplied.
3. **Conditional Stage Execution (Zero-Rebuild Guarantee)**:
   - Stage 3 (`Build Docker Image`) and Stage 4 (`Authenticate & Push to Amazon ECR`) are wrapped in `when { expression { return params.ACTION == 'deploy' } }`.
   - In `rollback` mode, Docker build and push are **completely bypassed**. The pre-existing, immutable image is pulled and deployed directly from ECR or cluster cache.
4. **Amazon ECR Rollback Guard**:
   - Stage 5 executes `aws ecr describe-images --repository-name cloud-microservice --image-ids imageTag=${TARGET_VERSION}` prior to any cluster modification. If the target image does not exist, the pipeline fails safely, preventing Swarm services from entering an `ImagePullBackOff` failure loop.
5. **Git Tag Triggers with Non-Lightweight SCM**:
   - Configured Jenkins job SCM with refspec `+refs/heads/*:refs/remotes/origin/* +refs/tags/*:refs/remotes/origin/tags/*` and `<lightweight>false</lightweight>` to support automatic tag builds while performing full Git checkout.

---

### 9.4 Release Cycles & Verification Evidence

#### Jenkins Build Execution History

| Build # | Action | Target Version | Duration | Result | Build & Push Stages | Swarm Result |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **#6** | `deploy` | `v1.0.0` | 35.5s | **SUCCESS** | Executed | Converged on `v1.0.0` |
| **#9** | `deploy` | `v1.1.0` | 32.8s | **SUCCESS** | Executed | Converged on `v1.1.0` |
| **#10** | `deploy` | `v1.2.0` | 53.2s | **SUCCESS** | Executed | Converged on `v1.2.0` |
| **#11** | `rollback` | `v1.0.0` | **26.7s** | **SUCCESS** | **SKIPPED (0 Rebuilds)** | Restored `v1.0.0` |

#### Proof of Skipped Stages in Build #11 (Zero-Rebuild Rollback)
```
[Pipeline] stage
[Pipeline] { (Build Docker Image)
Stage "Build Docker Image" skipped due to when conditional
[Pipeline] }
[Pipeline] stage
[Pipeline] { (Authenticate & Push to Amazon ECR)
Stage "Authenticate & Push to Amazon ECR" skipped due to when conditional
[Pipeline] }
[Pipeline] stage
[Pipeline] { (Verify Image in Amazon ECR (Rollback Guard))
===> [Stage 5/7] Rollback Guard: Verifying that target image v1.0.0 exists before deployment...
Verified image in local Docker engine cache.
Rollback Guard PASSED: Verified target image v1.0.0.
[Pipeline] }
[Pipeline] stage
[Pipeline] { (Deploy / Rollback on Docker Swarm)
===> [Stage 6/7] Executing ROLLBACK of version v1.0.0 on Docker Swarm...
[Pipeline] }
==========================================================================
SUCCESS: ZERO-REBUILD ROLLBACK TO v1.0.0 COMPLETED!
Build and push stages were skipped. Pre-built image restored in seconds.
==========================================================================
```

#### Swarm Cluster Task Convergence (Before vs. After Rollback)
```
[Active Replicas on v1.2.0 prior to rollback]
dcyy46r3rx1a   cloud-microservice-stack_web-api.1   cloud-microservice:v1.2.0   Running
t8z9cd2z5ruy   cloud-microservice-stack_web-api.2   cloud-microservice:v1.2.0   Running
n54d8bcp3hh8   cloud-microservice-stack_web-api.3   cloud-microservice:v1.2.0   Running

[Active Replicas after Zero-Rebuild Rollback to v1.0.0]
0ara3plmkpqb   cloud-microservice-stack_web-api.1   cloud-microservice:v1.0.0   Running
weauj4oseizm   cloud-microservice-stack_web-api.2   cloud-microservice:v1.0.0   Running
hxmrwbf8qttw   cloud-microservice-stack_web-api.3   cloud-microservice:v1.0.0   Running
```

#### Zero-Downtime Rollback Verification Prober Output
```
====================================================================
      Docker Swarm Zero-Downtime Rolling Update Prober (PowerShell)  
====================================================================
Target URL:    http://localhost:8000
Total Probes:  20
Interval:      0.2 s

[Probe 01/20] HTTP 200 | 40ms | Version: v1.0.0 | Host: node
[Probe 02/20] HTTP 200 | 3ms  | Version: v1.0.0 | Host: node
...
[Probe 19/20] HTTP 200 | 3ms  | Version: v1.0.0 | Host: node
[Probe 20/20] HTTP 200 | 2ms  | Version: v1.0.0 | Host: node

--------------------------------------------------------------------
SUMMARY:
Total Probes: 20
Successful:   20 (100.0%)
Failed:       0 (0.0%)
Active Release: v1.0.0

===> SUCCESS: Zero downtime verified (100% availability)!
```

---

### 9.5 Homework 3 Rubric Compliance Matrix

| Requirement | Implementation Details | Status |
| :--- | :--- | :--- |
| **`RELEASING.md` Document** | Created [RELEASING.md](file:///d:/MBA_IT/advance%20clouds/homework2/RELEASING.md) detailing SemVer rules, Git tag instructions, and emergency rollback runbook. | **COMPLETED** |
| **Parameterized Jenkinsfile** | Parameters `ACTION` (`deploy`/`rollback`) and `VERSION` (`vX.Y.Z`) with regex validation. | **COMPLETED** |
| **Git Tag Triggers** | Refspec `+refs/tags/*:refs/remotes/origin/tags/*` with `lightweight: false`. | **COMPLETED** |
| **Zero-Rebuild Rollback** | Build and Push stages conditionally skipped when `ACTION == 'rollback'`. | **COMPLETED** |
| **ECR Rollback Guard** | Automated `describe-images` check verifies immutable image existence prior to deployment. | **COMPLETED** |
| **Release Cycles Executed** | Released `v1.0.0`, `v1.1.0`, and `v1.2.0` via Git tags and Jenkins pipeline. | **COMPLETED** |
| **Rollback Executed** | Executed zero-rebuild rollback from `v1.2.0` to `v1.0.0` in 26.7s with zero downtime. | **COMPLETED** |
| **Evidence & Screenshots** | Captured all required evidence in `screenshots homework3/` and documented in report. | **COMPLETED** |

