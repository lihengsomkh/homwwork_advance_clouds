# Release Management, Semantic Versioning & Zero-Rebuild Rollback Guide

**Project:** AWS Docker Swarm Cloud Microservice  
**Course:** Advanced Cloud Computing (MBA IT)  
**Author:** Liheng  
**Document:** `RELEASING.md` — Release Operations & Rollback Runbook  

---

## 1. Semantic Versioning Specification (SemVer)

All releases across this repository strictly follow the **Semantic Versioning 2.0.0** specification, prefixed with the letter `v`:

$$\text{Format: } \mathbf{v\langle MAJOR\rangle.\langle MINOR\rangle.\langle PATCH\rangle}$$

### Version Component Guidelines

| Component | When to Increment | Example Transition | Description |
| :--- | :--- | :--- | :--- |
| **`MAJOR`** | Breaking Changes | `v1.2.0` $\rightarrow$ `v2.0.0` | Incompatible API changes, major architecture shifts, schema overhauls. |
| **`MINOR`** | New Features | `v1.0.0` $\rightarrow$ `v1.1.0` | Backward-compatible features, new endpoints, non-breaking telemetry enhancements. |
| **`PATCH`** | Bug Fixes | `v1.1.0` $\rightarrow$ `v1.1.1` | Backward-compatible bug fixes, performance patches, security updates. |

> [!IMPORTANT]
> **Strict Immutability Rule:** Once an image tag is published to Amazon ECR (e.g., `410768350356.dkr.ecr.ap-southeast-2.amazonaws.com/cloud-microservice:v1.0.0`), it is **strictly immutable**. Mutable tags like `latest` are **prohibited** in production release cycles to prevent non-deterministic deployments and ensure verifiable rollbacks.

---

## 2. Git Release Tagging Protocol

Production deployments are governed strictly by annotated Git release tags.

### 2.1 Creating and Publishing a Release Tag

```bash
# 1. Ensure your local branch is clean and fully synchronized with origin/main
git checkout main
git pull origin main

# 2. Create an annotated Git tag with release notes
git tag -a v1.0.0 -m "Release v1.0.0: Initial production baseline deployment"

# 3. Verify the tag locally
git tag -n -l "v*"

# 4. Push the tag to GitHub to initiate the CI/CD pipeline
git push origin v1.0.0
```

### 2.2 Releasing Multiple Iterations

```bash
# Feature Release v1.1.0 (Telemetry & Banner update)
git tag -a v1.1.0 -m "Release v1.1.0: Add enhanced telemetry and service banner"
git push origin v1.1.0

# Performance Release v1.2.0 (Latency optimization & dashboard enhancements)
git tag -a v1.2.0 -m "Release v1.2.0: Real-time Swarm load balancing prober"
git push origin v1.2.0
```

### 2.3 Deleting an Accidental Tag

If a tag was created in error before deployment:

```bash
# Delete local tag
git tag -d vX.Y.Z

# Delete remote tag on GitHub
git push origin :refs/tags/vX.Y.Z
```

---

## 3. Parameterized CI/CD Pipeline Architecture

The declarative Jenkins pipeline (`Jenkinsfile`) operates in two distinct operational modes:

1. **`deploy` Mode (Automated / Manual Release)**:
   - Triggered automatically by Git tags matching `refs/tags/*` or triggered manually with `ACTION=deploy`.
   - **Executes**: Checkout $\rightarrow$ Lint $\rightarrow$ **Build Docker Image** $\rightarrow$ **Push to Amazon ECR** $\rightarrow$ ECR Guard Verification $\rightarrow$ Swarm Rolling Deployment.
2. **`rollback` Mode (Zero-Rebuild Emergency Rollback)**:
   - Triggered manually via Jenkins UI with `ACTION=rollback` and target `VERSION=vX.Y.Z`.
   - **SKIPS**: Build and Push stages completely (no source code recompilation).
   - **Executes**: ECR Guard Verification (confirms target image tag exists in ECR) $\rightarrow$ Immediate Swarm Rolling Redeployment.

### Pipeline Control Parameters

```groovy
parameters {
    choice(name: 'ACTION', choices: ['deploy', 'rollback'], 
           description: 'Select deployment or emergency zero-rebuild rollback')
    string(name: 'VERSION', defaultValue: 'v1.0.0', 
           description: 'Target Semantic Version (e.g. v1.0.0, v1.1.0, v1.2.0)')
}
```

---

## 4. Emergency Zero-Rebuild Rollback Runbook

When an anomaly, performance regression, or critical defect is detected in a live release (e.g., `v1.2.0`), follow this procedure to restore service to a known-healthy release (e.g., `v1.0.0`) in seconds with **zero downtime** and **zero code rebuilds**.

### 4.1 Rollback Steps in Jenkins

1. Open Jenkins: [http://localhost:8080/job/cloud-microservice-pipeline/](http://localhost:8080/job/cloud-microservice-pipeline/)
2. In the left navigation menu, click **Build with Parameters**.
3. Configure the parameters:
   - **`ACTION`**: Select **`rollback`**
   - **`VERSION`**: Enter the target version to restore, e.g., **`v1.0.0`**
4. Click **Build**.

### 4.2 Why Zero-Rebuild is Architecturally Superior

```
[Normal Deploy]:   Code Checkout -> Docker Build (2 min) -> ECR Push (1 min) -> Swarm Deploy (30s)
[Zero-Rebuild]:    ECR Guard Verify (1s) -----------------------------------> Swarm Deploy (15s)
                                                                             ^^^^^^^^^^^^^^^^^^
                                                                             Immediate Recovery!
```

- **Speed**: Bypasses compile, dependency installation, and container build times.
- **Reliability**: Eliminates the risk of build-time failures, upstream package repository outages, or altered build contexts.
- **Auditability**: Uses the exact bit-for-bit container image previously tested and approved in production.

### 4.3 The ECR Verification Guard

Before touching the Swarm cluster during a rollback, the pipeline executes an automated guard:

```bash
aws ecr describe-images \
    --repository-name cloud-microservice \
    --image-ids imageTag=${TARGET_VERSION} \
    --region ${AWS_REGION}
```

If the requested rollback version tag does not exist in Amazon ECR, the pipeline **aborts immediately** with an error, preventing the Swarm service from entering an `ImagePullBackOff` loop.

---

## 5. Post-Rollback Verification & Health Checks

After a rollback completes, run the following commands to confirm that the cluster has converged onto the restored release:

```bash
# 1. Verify running image tag on Docker Swarm
docker service ls --filter "name=cloud-microservice-stack"
docker service ps cloud-microservice-stack_web-api

# 2. Probe application endpoint
curl http://<SWARM_MANAGER_IP>/

# 3. Run continuous zero-downtime prober
./scripts/verify-rolling-update.sh http://<SWARM_MANAGER_IP> 20 0.2
```

---

## 6. Audit Trail & Compliance Matrix

| Requirement | Implementation Detail | Status |
| :--- | :--- | :--- |
| **Strict SemVer** | `vMAJOR.MINOR.PATCH` with regex validation (`^v[0-9]+\.[0-9]+\.[0-9]+$`) | **ENFORCED** |
| **No Mutable Tags** | Eliminates `latest` in favor of immutable version tags | **ENFORCED** |
| **Git Tag Triggers** | SCM refspec configured for `+refs/tags/*:refs/remotes/origin/tags/*` | **CONFIGURED** |
| **Zero-Rebuild Rollback** | Skips build & push; redeploys verified ECR image tag directly | **ENFORCED** |
| **ECR Image Guard** | `describe-images` checks existence before rolling update | **ACTIVE** |
