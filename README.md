# GitHub Actions → AWS CDK Connectivity Test

A small, reusable TypeScript CDK project that proves GitHub Actions can authenticate to AWS and deploy with AWS CDK. It uses **GitHub OIDC**, so no AWS access keys are stored in GitHub.

The pipeline runs in three stages, so you can find exactly where a problem is:

| Stage | What it proves | Needs |
|---|---|---|
| 1. Identity | GitHub can assume your IAM role (`aws sts get-caller-identity`) | OIDC provider + IAM role |
| 2. Synth | The CDK app typechecks, passes unit tests, and synthesizes | Node + dependencies |
| 3. Deploy | CDK can deploy into the account and the result is readable | CDK bootstrap |

The deployed stack creates **one SSM parameter** (free, standard tier) containing the commit SHA and run ID. Stage 3 reads it back to confirm the deploy really reached AWS.

---

## 1. Prerequisites (mandatory)

### On your machine
| Tool | Version | Check |
|---|---|---|
| Node.js | 22 LTS or newer | `node --version` |
| npm | ships with Node | `npm --version` |
| AWS CLI | v2 | `aws --version` |
| git | any recent | `git --version` |
| GitHub CLI (optional) | any | `gh --version`, lets setup set repo variables for you |

### In AWS
- An AWS account and an identity with admin-level rights (IAM, CloudFormation, S3, ECR, SSM) for the **one-time setup only**.
- Working local credentials: `aws configure`, or `aws configure sso` followed by `aws sso login`.
- A chosen region, used consistently everywhere.

### In GitHub
- A repository you have admin rights on (to add variables).
- GitHub Actions enabled (Settings → Actions → General).

---

## 2. Project structure

```
gh-cdk-connectivity/
├── .github/
│   ├── actions/aws-cdk-setup/action.yml   # Reusable composite action: Node + deps + OIDC login
│   └── workflows/cdk-connectivity.yml     # Staged pipeline: identity → synth → deploy
├── bin/app.ts                             # CDK entry point
├── lib/
│   ├── config/environment.ts              # Environments (dev/staging/prod), tags, naming
│   ├── constructs/deployment-marker.ts    # Reusable construct (SSM deployment marker)
│   ├── constructs/index.ts                # Barrel export
│   ├── stacks/connectivity-test-stack.ts  # The test stack
│   └── utils/tags.ts                      # Reusable tagging helper
├── test/connectivity-test-stack.test.ts   # Jest unit tests (CDK assertions)
├── iam/
│   ├── github-trust-policy.template.json      # OIDC trust policy (repo + branch scoped)
│   └── github-permissions-policy.template.json # Least-privilege role policy
├── scripts/
│   ├── config.env.example                 # Your org/repo/region settings
│   ├── check-prereqs.sh                   # Verifies tools and AWS credentials
│   ├── setup-aws.sh                       # One-time AWS setup (idempotent)
│   ├── verify-local.sh                    # Runs the pipeline checks locally
│   └── teardown.sh                        # Cleans up
├── cdk.json  package.json  tsconfig.json  jest.config.js  .nvmrc
```

---

## 3. Setup, step by step

### Step 1: Configure the scripts

```bash
cp scripts/config.env.example scripts/config.env
```

Edit `scripts/config.env`:

```bash
GITHUB_ORG=your-org-or-username   # case-sensitive, exactly as on GitHub
GITHUB_REPO=your-repo-name
BRANCH=main
AWS_REGION=us-east-1
AWS_PROFILE=                      # optional named profile
ROLE_NAME=gh-cdk-deploy-role
```

### Step 2: Install dependencies and create the lock file

```bash
npm install
```

This creates `package-lock.json`. **Commit it**: the pipeline uses `npm ci` when a lock file exists, which gives reproducible builds. (Without it the pipeline still works but falls back to `npm install` and warns.)

### Step 3: Run the one-time AWS setup

```bash
./scripts/setup-aws.sh
```

The script is idempotent and does the following:

1. Checks your tools and AWS credentials.
2. Creates the GitHub OIDC identity provider (`token.actions.githubusercontent.com`, audience `sts.amazonaws.com`) if it doesn't exist.
3. Creates or updates the IAM role `gh-cdk-deploy-role`, trusted **only** by `repo:ORG/REPO:ref:refs/heads/BRANCH`.
4. Attaches a least-privilege policy: assume the CDK bootstrap roles (`cdk-hnb659fds-*`) and read the deployment marker.
5. Runs `cdk bootstrap aws://ACCOUNT/REGION`.
6. Sets the GitHub repository variables, if the `gh` CLI is installed and logged in.

At the end it prints the three values the workflow needs.

### Step 4: Add GitHub repository variables (if not set automatically)

Settings → Secrets and variables → Actions → **Variables** tab → New repository variable:

| Name | Example value |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/gh-cdk-deploy-role` |
| `AWS_REGION` | `us-east-1` |
| `AWS_ACCOUNT_ID` | `123456789012` |

These are variables rather than secrets because none of them are sensitive. No access keys are stored anywhere.

### Step 5: Verify locally (optional but recommended)

```bash
./scripts/verify-local.sh
```

Runs typecheck, unit tests, `aws sts get-caller-identity`, and `cdk synth`, the same checks as the pipeline.

### Step 6: Push to GitHub

```bash
git init
git add .
git commit -m "GitHub to AWS CDK connectivity test"
git branch -M main
git remote add origin https://github.com/ORG/REPO.git
git push -u origin main
```

Note that **a push to `main` runs all three stages automatically**. If you want to go stage by stage, push to another branch first and merge later, or simply re-run stages manually as below.

---

## 4. Running the staged test

Go to **Actions → CDK Connectivity Test → Run workflow**, select branch `main`, then choose a stage.

### Stage 1: `identity`
The log should show:

```json
{
  "UserId": "AROA...:gh-identity-1234567890",
  "Account": "123456789012",
  "Arn": "arn:aws:sts::123456789012:assumed-role/gh-cdk-deploy-role/gh-identity-1234567890"
}
```

followed by a notice that GitHub is connected to the account. **If you see the expected role in `Arn` and the right account, the GitHub ↔ AWS connection works.**

### Stage 2: `synth`
Typecheck, unit tests, and `cdk synth` pass. A `cdk-out` artifact appears on the run summary page.

### Stage 3: `deploy`
CloudFormation stack `gh-cdk-connectivity-dev` is created. The final step reads the SSM parameter and confirms it contains the current commit SHA:

```json
{"commitSha":"a1b2c3...","runId":"1234567890","triggeredBy":"your-username"}
```

You can also check it yourself:

```bash
aws ssm get-parameter --name /gh-cdk-connectivity/dev/deployment-marker --query Parameter.Value --output text
```

---

## 5. Reusing this project

**Add an environment.** Add it to `ENVIRONMENTS` in `lib/config/environment.ts`, then change `CDK_ENV` in the workflow (or pass `-c env=staging` locally). Extend the role policy's SSM resource if you change the app name.

**Use the construct elsewhere.** Copy `lib/constructs/deployment-marker.ts`; it has no dependency on this stack.

**Use the composite action in another workflow:**

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: actions/checkout@v5
  - uses: ./.github/actions/aws-cdk-setup
    with:
      role-to-assume: ${{ vars.AWS_ROLE_ARN }}
      aws-region: ${{ vars.AWS_REGION }}
  - run: npx cdk deploy --all --require-approval never
```

**Allow other branches, PRs, or GitHub Environments.** Edit the `sub` condition in `iam/github-trust-policy.template.json` and re-run `setup-aws.sh`:

| Trigger | `sub` value |
|---|---|
| One branch | `repo:ORG/REPO:ref:refs/heads/main` |
| Any branch | `repo:ORG/REPO:ref:refs/heads/*` |
| Pull requests | `repo:ORG/REPO:pull_request` |
| GitHub Environment | `repo:ORG/REPO:environment:prod` |

If a job uses `environment: prod`, the token's `sub` becomes the environment form, so the branch form will **not** match.

**Add real resources.** Add constructs to `ConnectivityTestStack` or create new stacks in `lib/stacks/`. The deploy role works through the CDK bootstrap roles, so new resource types need no change to the GitHub role.

---

## 6. Version compatibility

| Component | Version | Notes |
|---|---|---|
| Node.js | 22 LTS (`.nvmrc`) | Node 20 reached end of life in April 2026 |
| `aws-cdk-lib` | `^2.180.0` | CDK v2 only |
| `aws-cdk` (CLI) | `^2.1000.0` | Since early 2025 the CLI is versioned separately (2.1xxx). The CLI must be at least as new as the library; keeping both on `^` ranges satisfies this |
| `constructs` | `^10.4.2` | Required peer of CDK v2 |
| TypeScript | `~5.6.3` | |
| Jest / ts-jest | `^29` | |
| GitHub actions | `checkout@v5`, `setup-node@v5`, `configure-aws-credentials@v4`, `upload-artifact@v4` | |

Check what got installed with `npm ls aws-cdk aws-cdk-lib constructs`. If you see "Cloud assembly schema version mismatch", upgrade the CLI: `npm install -D aws-cdk@latest`.

---

## 7. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Repository variable AWS_ROLE_ARN is not set` | Variables missing or added as secrets | Add them under the **Variables** tab |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | `sub` doesn't match repo/branch, or OIDC provider missing | Check `config.env` spelling (case-sensitive), re-run `setup-aws.sh` |
| `Credentials could not be loaded` | Missing `id-token: write` | Keep the `permissions` block in the workflow |
| `Account mismatch` | Wrong `AWS_ACCOUNT_ID` | Set it to the account that owns the role |
| `has not been bootstrapped` / bootstrap version too low | Bootstrap missing or in another region | Re-run `setup-aws.sh` with the same region as `AWS_REGION` |
| `AccessDenied` on `sts:AssumeRole` (cdk-hnb659fds-…) | Policy missing or custom bootstrap qualifier | Check the role policy; adjust the ARN if you bootstrapped with a custom `--qualifier` |
| `Unknown environment` | `-c env=` not in `ENVIRONMENTS` | Use `dev`, `staging`, `prod`, or add one |
| `Dependencies lock file is not found` | Old setup-node config | Commit `package-lock.json` |
| Marker verification fails with `AccessDenied` | `ssm:GetParameter` missing | Re-run `setup-aws.sh`; check the app name matches the policy |

---

## 8. Cleanup

```bash
./scripts/teardown.sh               # delete the test stack only
./scripts/teardown.sh --all         # also delete the IAM role
./scripts/teardown.sh --all --oidc  # also delete the OIDC provider (asks for confirmation)
```

The `CDKToolkit` bootstrap stack is left in place because other CDK apps may use it. Remove it from the CloudFormation console if you no longer need it (empty its S3 bucket first).

---

## Security notes

- No long-lived AWS keys: GitHub receives short-lived credentials (1 hour max) via OIDC.
- The role trusts a single repo and branch by default.
- The role can only assume CDK bootstrap roles and read this project's SSM parameters; actual resource creation happens through the CDK bootstrap roles.
- Every session is named (`gh-identity-<run_id>`, `gh-deploy-<run_id>`), so you can trace it in CloudTrail.
