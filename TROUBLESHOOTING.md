# Troubleshooting Notes — DevOps Microservices Platform

A full log of every issue encountered during deployment, the root cause, and how it was resolved.

---

## 1. Jenkinsfile — `AWS_ACCOUNT_ID` Outside Pipeline Block

**Error:** Pipeline failed to parse / environment variables were empty  
**Root cause:** The `sh()` call to fetch the AWS account ID was placed between the `agent` and `parameters` blocks — outside any valid pipeline block. Jenkins declarative pipelines only allow `sh()` inside `environment {}`.  
**Fix:** Moved `AWS_ACCOUNT_ID = sh(...)` inside the `environment {}` block.

---

## 2. YAML Files Stored as Single Line with `\n` Literals

**Files affected:** `app-ingress.yaml`, `argocd-ingress.yaml`  
**Root cause:** Files were created/copied incorrectly — stored as a single line with literal `\n` text instead of actual newlines, making them invalid YAML.  
**Fix:** Rewrote both files with proper newline formatting.

---

## 3. Terraform — Provider Version Mismatch

**Error:** Lock file resolved `~> 5.95` but installed binary was `6.51.0`  
**Root cause:** Provider version constraint didn't match the downloaded binary.  
**Fix:** Updated `provider.tf` version constraint from `~> 5.95` to `~> 6.0`.

---

## 4. Terraform — ECR Repos Missing Security Config

**Root cause:** ECR repositories had no image scanning, mutable tags, or lifecycle policies.  
**Fix:** Added `image_tag_mutability = "IMMUTABLE"`, `scan_on_push = true`, and lifecycle policies to expire images beyond 10.

---

## 5. Terraform — Hardcoded AWS Account ID in `eks.tf`

**Root cause:** Account ID `589389425618` was hardcoded in `access_entries` ARNs.  
**Fix:** Replaced with `data.aws_caller_identity.current.account_id`.

---

## 6. Terraform — EKS Access Entry Conflict (409)

**Error:** `ResourceInUseException: The specified access entry resource is already in use`  
**Root cause:** `enable_cluster_creator_admin_permissions = true` automatically creates an access entry for the caller (root). Having the same principal also in `access_entries` caused a duplicate.  
**Fix:** Removed `root_admin` from `access_entries` — it's already handled by `enable_cluster_creator_admin_permissions`.

---

## 7. Terraform — VPC Module Pinned to Non-Existent Tag

**Error:** `error: pathspec 'v3.0.0' did not match any file(s) known to git`  
**Root cause:** VPC module source was updated to `?ref=v3.0.0` but the repo only has a `main` branch — no tags exist.  
**Fix:** Reverted to `?ref=main`.

---

## 8. Terraform — `.tf` Files Renamed to `.bkp`

**Error:** Terraform couldn't find `eks.tf`, `ecr.tf`, and other files  
**Root cause:** Files were manually renamed to `.bkp` extension, making them invisible to Terraform.  
**Fix:** Restored all files from `.bkp` back to `.tf` extension with original content preserved.

---

## 9. Terraform — Prod Backend Missing State Locking

**Root cause:** `prod/backend.tfvars` had no `dynamodb_table` or `encrypt = true`.  
**Fix:** Added `dynamodb_table = "terraform-state-lock-prod"` and `encrypt = true`.

---

## 10. `cicd-tools` — `filebase64()` Warning

**Warning:** `Value is base64 encoded. If you want to use base64 encoding, please use the user_data_base64 argument`  
**Root cause:** Used `filebase64("jenkins.sh")` for `user_data`. Terraform's `user_data` handles base64 internally — using `filebase64()` double-encodes it.  
**Fix:** Changed to `file("jenkins.sh")`.

---

## 11. `cicd-tools` — Route53 CNAME Conflict

**Error:** `RRSet of type A with DNS name jenkins.vosukula.online is not permitted because a conflicting RRSet of type CNAME already exists`  
**Root cause:** The ALB Ingress Controller had already created a CNAME for `jenkins.vosukula.online` pointing to the ALB. AWS Route53 does not allow an A record and a CNAME to share the same name.  
**Fix:** Commented out both `aws_route53_record` blocks in `main.tf`. DNS is owned by the ALB controller.

---

## 12. Jenkins `user_data` — GPG Signature Verification Failed

**Error:** `repomd.xml GPG signature verification error: Bad GPG signature`  
**Root cause:** The Jenkins GPG key import was inside an `if [ ! -f /etc/yum.repos.d/jenkins.repo ]` guard — on fresh instances the cached metadata could mismatch the key.  
**Fix:** Removed the `if` guard — always re-download the repo file and re-import the GPG key. Added `dnf clean metadata` and `dnf makecache -y` right after.

---

## 13. Jenkins `user_data` — Interactive GPG Prompt Hung Script

**Symptom:** Script hung indefinitely at `Is this ok [y/N]:` during `dnf makecache`  
**Root cause:** When `dnf` encounters a new GPG key during metadata fetch, it prompts for confirmation. `user_data` runs non-interactively — nothing to answer the prompt.  
**Fix:** Added `-y` flag: `dnf makecache -y`.

---

## 14. `setup-jenkins-agent.sh` — Wrong Java Package Name

**Error:** `No match for argument: java-21-amazon-corretto`  
**Root cause:** `java-21-amazon-corretto` is not available in standard RHEL 9 repos. It requires the Amazon Corretto repo to be added separately.  
**Fix:** Changed to `java-21-openjdk java-21-openjdk-devel` which is in the standard RHEL repo.

---

## 15. `setup-jenkins-agent.sh` — Broken Multi-line Shell Commands

**Root cause:** Several `dnf` and `aws` commands were split across lines without `\` line continuations, causing bash to treat each line as a separate command and fail.  
**Fix:** Added proper `\` line continuations to all multi-line commands.

---

## 16. Helm Install — `context deadline exceeded`

**Error:** `Error: UPGRADE FAILED: context deadline exceeded`  
**Root cause:** `--wait --timeout 5m` caused Helm to timeout waiting for the Jenkins pod — which was blocked by a missing PVC/secret.  
**Fix:** Removed `--wait --timeout` from Helm command. Used `kubectl rollout status statefulset/jenkins` separately with a longer 300s timeout.

---

## 17. Jenkins Pod — Wrong Workload Type in Rollout Status

**Error:** `Error from server (NotFound): deployments.apps "jenkins" not found`  
**Root cause:** Script used `kubectl rollout status deployment/jenkins` but Jenkins Helm chart deploys as a **StatefulSet**, not a Deployment.  
**Fix:** Changed to `kubectl rollout status statefulset/jenkins -n jenkins`.

---

## 18. ArgoCD Install — CRD Too Large for Client-Side Apply

**Error:** `The CustomResourceDefinition "applicationsets.argoproj.io" is invalid: metadata.annotations: Too long: may not be more than 262144 bytes`  
**Root cause:** `kubectl apply` stores the full manifest in a `last-applied-configuration` annotation. The ArgoCD CRD exceeds the 262144 byte limit.  
**Fix:** Added `--server-side` flag to `kubectl apply`. Server-side apply manages field ownership on the server and doesn't use the annotation.

---

## 19. Jenkins Ingress — ACM Certificate Placeholder Not Replaced

**Error:** `CertificateNotFound: Certificate 'REPLACE_WITH_ACM_CERT_ARN' not found`  
**Root cause:** The `jenkins-ingress.yaml` had a placeholder `REPLACE_WITH_ACM_CERT_ARN` that was never replaced with the real ACM ARN before applying.  
**Fix:** Updated all ingress files with the real ARN:  
`arn:aws:acm:us-east-1:589389425618:certificate/7c22798a-e5f0-49dd-9533-4cc0f5659027`

---

## 20. Jenkins Pod Stuck in `Init:0/2` for 50+ Minutes

**Error:** `MountVolume.SetUp failed for volume "jenkins-secrets": secret "jenkins-admin-secret" not found`  
**Root cause:** `jenkins-values.yaml` references `existingSecret: jenkins-admin-secret` but the Kubernetes secret was never created in the cluster before installing Jenkins.  
**Fix:** Created the secret manually:
```bash
kubectl create secret generic jenkins-admin-secret \
  --from-literal=jenkins-admin-user=admin \
  --from-literal=jenkins-admin-password=<your-password> \
  -n jenkins
```
Pod automatically picked up the secret and progressed through `Init:1/2` → `Init:2/2` → `Running`.

---

## Key Lessons

| Area | Lesson |
|---|---|
| Kubernetes Secrets | Always create `existingSecret` references before deploying the Helm chart |
| ACM Certs | Replace all `REPLACE_WITH_ACM_CERT_ARN` placeholders before applying ingress manifests |
| Helm + StatefulSets | Jenkins deploys as a StatefulSet — use `rollout status statefulset/` not `deployment/` |
| ArgoCD CRDs | Always use `--server-side` for ArgoCD installs to avoid annotation size limit |
| Shell Scripts | All multi-line commands need `\` continuations — bare newlines break execution |
| Terraform Access Entries | Don't duplicate principals between `enable_cluster_creator_admin_permissions` and `access_entries` |
| Route53 + ALB | ALB Ingress Controller owns DNS via CNAME — don't create conflicting A records in Terraform |
| user_data Scripts | Always use `-y` flags on dnf/yum commands — interactive prompts hang non-interactive scripts |
| ECR Immutable Tags | Never push `:latest` to IMMUTABLE repos — use unique tags (BUILD_NUMBER or semver) |
| Jenkins Agent Disk Space | Jenkins auto-marks agents offline when free disk < threshold. Lower threshold or free space with `docker system prune -af` |
| Jenkins Executor Queue | Stuck builds hold executor slots — abort old builds before starting new ones |
| ACM Wildcard Cert | Apex cert (`vosukula.online`) does NOT cover subdomains. Use `*.vosukula.online` wildcard for ALB ingress |
