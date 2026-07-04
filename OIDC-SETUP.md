# GitHub Actions OIDC + AWS — Setup Guide

How to connect GitHub Actions to AWS securely using OIDC (no access keys stored).

---

## What is OIDC?

Instead of storing AWS access keys in GitHub Secrets, GitHub sends a signed token to AWS and says "I'm this repo, give me temporary credentials." AWS validates it and returns 15-minute credentials.

```
GitHub Actions workflow starts
    ↓
GitHub generates OIDC JWT token (signed, contains repo info)
    ↓
Sends to AWS STS: "I'm repo ShivaKrishna44/devops-microservices-nojenkins"
    ↓
AWS checks trust policy on the IAM role: "Is this repo allowed?" → YES
    ↓
AWS returns temporary credentials (15 min expiry)
    ↓
Workflow uses creds → pushes to ECR, accesses EKS, etc.
    ↓
Credentials auto-expire → no cleanup needed
```

**No static keys. No secrets to rotate. No risk of key leakage.**

---

## Step 1: Add Identity Provider in AWS

1. Go to: **AWS Console → IAM → Identity Providers → Add Provider**
2. Select: **OpenID Connect**
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`
5. Click **Get thumbprint** (verifies the connection)
6. Click **Add provider**

**What this does:** Tells AWS "I trust tokens from GitHub's OIDC service."

---

## Step 2: Create IAM Role for GitHub Actions

1. Go to: **IAM → Roles → Create role**
2. Trusted entity type: **Web Identity**
3. Identity provider: select `token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`
5. Fill in conditions:
   - GitHub organization: `ShivaKrishna44`
   - GitHub repository: `devops-microservices-nojenkins`
   - GitHub branch: `*` (all branches)
6. Click **Next**

**What this does:** Creates a role that ONLY your specific repo can assume. No other repo in the world can use this role.

---

## Step 3: Attach Permissions to the Role

1. Search for: `AdministratorAccess`
2. Select it → Next
3. Role name: `github-actions-admin-role`
4. Click **Create role**

**What this does:** Gives the role full AWS access so the pipeline can push to ECR, access EKS, create resources, etc.

⚠️ **For production:** Replace `AdministratorAccess` with a scoped policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## Step 4: Verify Trust Policy

After creating the role, verify the trust policy is correct:

1. Go to: **IAM → Roles → `github-actions-admin-role` → Trust relationships tab**
2. It should look like this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::589389425618:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ShivaKrishna44/devops-microservices-nojenkins:*"
        }
      }
    }
  ]
}
```

If it doesn't match, click **Edit trust policy** and paste the above.

---

## Step 5: Update GitHub Actions Workflow

In `.github/workflows/ci-cd.yml`, add permissions and use `role-to-assume`:

```yaml
# Top-level — required for OIDC token
permissions:
  id-token: write     # Allows GitHub to generate OIDC token
  contents: write     # Allows git push for Helm values

env:
  AWS_ROLE_ARN: arn:aws:iam::589389425618:role/github-actions-admin-role

# In each job step:
- name: Configure AWS Credentials (OIDC)
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ env.AWS_ROLE_ARN }}
    aws-region: us-east-1
```

**No `aws-access-key-id` or `aws-secret-access-key` needed.** ✅

---

## Step 6: Test the Connection

Push any change to trigger the workflow:

```bash
echo "# test" >> app/order-service/app.py
git add . && git commit -m "test OIDC" && git push
```

Check: **GitHub → Actions tab → CI/CD Pipeline → look for "Configure AWS Credentials" step**

If successful, you'll see:
```
Assuming role with OIDC
Credentials configured for arn:aws:iam::589389425618:role/github-actions-admin-role
```

---

## Troubleshooting

| Error | Fix |
|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Trust policy doesn't match your repo — check `StringLike` condition |
| `No OpenIDConnect provider found` | OIDC provider not added in IAM — redo Step 1 |
| `Error: Could not assume role` | Check role ARN spelling in workflow matches exactly |
| `AccessDenied on ecr:GetAuthorizationToken` | Role permissions don't include ECR access — check attached policy |
| Workflow succeeds but ECR push fails | Role has OIDC but no ECR permissions — attach ECR policy |

---

## Comparison: Access Keys vs OIDC

| Aspect | Access Keys (old) | OIDC (current) |
|---|---|---|
| Storage | Static keys in GitHub Secrets | No keys stored anywhere |
| Rotation | Manual — must rotate keys periodically | Automatic — 15 min temp creds |
| Risk if leaked | Full AWS access until rotated | Token expires in 15 min |
| Scope | Any machine with the key can use it | Only your specific repo can use it |
| Setup | Create IAM user + keys + store in GitHub | Create role + trust policy |
| Best practice | ❌ Not recommended | ✅ AWS recommended approach |

---

## Role ARN for This Project

```
arn:aws:iam::589389425618:role/github-actions-admin-role
```

Used in: `.github/workflows/ci-cd.yml`


---

## Key Point: Nothing to Configure in GitHub

With OIDC, there is **zero configuration needed on the GitHub side**:

- ❌ No secrets to add in GitHub Settings
- ❌ No tokens to generate or rotate
- ❌ No GitHub App to install
- ❌ No OAuth configuration

**Everything is handled by:**
1. The workflow file (`permissions: id-token: write` + `role-to-assume`) — already in your code
2. The AWS IAM trust policy — already configured in AWS Console

Just push the code with the workflow file and it works automatically.
