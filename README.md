# Terraform AWS VPC Foundation — DEV and PROD

A production-style AWS network foundation, deployed as **two fully independent environments** (`dev`, `prod`) from the same reusable Terraform modules, with a GitHub Actions pipeline that authenticates to AWS via **GitHub OIDC** (no long-lived keys) and gates production behind a **GitHub Environment approval**.

Repository: <https://github.com/sabo1166/CICD-terraform-project-2-env>

> The S3 bucket in this project exists **only** to hold Terraform remote state. The infrastructure being managed is the VPC foundation.

## 1. What it demonstrates
Reusable modules · environment separation · remote state with S3-native locking · least-privilege IAM · GitHub OIDC · plan-on-PR / apply-on-merge CI/CD · approval-gated production · mocked-provider Terraform tests.

## 2. Architecture

```text
                        GitHub (sabo1166/CICD-terraform-project-2-env)
                                         |
                                  GitHub Actions
                  PR: fmt, validate, tests, plan dev + plan prod
                  main: plan dev -> APPLY dev -> plan prod -> [approval] -> APPLY prod
                                         |
                             OIDC token (short-lived)
                                         |
                        existing IAM role: GitHub-OIDC
                        (created outside this repo)
                                         |
                    +--------------------+--------------------+
                    |                                         |
                    v                                         v
        state: s3://<bucket>/dev/...              state: s3://<bucket>/prod/...
                    |                                         |
                    v                                         v
         VPC 10.0.0.0/16 (dev)                    VPC 10.1.0.0/16 (prod)
         1 NAT Gateway                            1 NAT Gateway per AZ
```

## 3. DEV vs PROD

| | dev | prod |
|---|---|---|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` |
| NAT Gateways | 1 (shared, cheaper) | 1 per AZ (resilient) |
| Flow-log retention | 14 days | 90 days |
| State key | `dev/terraform.tfstate` | `prod/terraform.tfstate` |
| Deploy | automatic on merge to `main` | after required-reviewer approval |
| AWS role (OIDC) | existing `GitHub-OIDC` (shared) | existing `GitHub-OIDC` (shared) |
| Provider | own `provider "aws"` + `default_tags` (Environment=dev) | own `provider "aws"` + `default_tags` (Environment=prod) |

Separation is by **state, CIDR, provider and name prefix** (`foundation-dev-*` / `foundation-prod-*`) within one AWS account. For stronger isolation use one AWS account per environment (see §14).

## 4. VPC design

```text
VPC (10.X.0.0/16)                      X = 0 dev, 1 prod
 ├─ Public   10.X.0.0/24, 10.X.1.0/24     route 0.0.0.0/0 -> Internet Gateway; hosts the NAT Gateway(s)
 ├─ Private app 10.X.10.0/24, 10.X.11.0/24  route 0.0.0.0/0 -> NAT Gateway (outbound only)
 └─ Private db  10.X.20.0/24, 10.X.21.0/24  NO default route (isolated)
Also: S3 gateway endpoint (free; keeps S3 traffic off the NAT), VPC flow logs -> CloudWatch,
      emptied default security group, web -> app -> db security groups.
```
Why each piece: the **NAT Gateway** gives private subnets controlled outbound access without any inbound path; **db subnets have no default route** so they stay isolated even if a security group is misconfigured; **flow logs** give an audit trail; the **S3 endpoint** avoids NAT per-GB charges.

## 5. Repository structure and modules

```text
.github/workflows/terraform.yml       entry: validate, then dev, then prod
.github/workflows/terraform-env.yml   reusable: plan (+ apply) one environment
bootstrap/                            state bucket only (local state, run once). No OIDC/IAM here.
docs/github-oidc-role.md              trust + permission requirements of the existing GitHub-OIDC role
environments/{dev,prod}/              thin roots: backend, provider, one module call, outputs
modules/foundation/                   composes the three modules below (+ flow-log log group)
modules/vpc/                          VPC, subnets, IGW, NAT, routes, S3 endpoint, flow log
modules/security-groups/              web/app/db tier security groups
modules/iam/                          least-privilege VPC flow-log role
scripts/bootstrap-state.sh            wrapper around bootstrap/
```
No resource is defined twice: each environment only calls `modules/foundation` with different inputs. Each module has typed, described, validated variables and outputs; `vpc`, `security-groups` and `foundation` have `terraform test` suites (mocked provider, no AWS access).

## 6. State management
- **Remote backend:** S3 bucket `foundation-tfstate-<account-id>` (SSE-S3, versioned, public access blocked, ACLs disabled, TLS-only, `prevent_destroy`).
- **Separation:** `dev/terraform.tfstate` and `prod/terraform.tfstate` — independent states. (The shared `GitHub-OIDC` role can reach both prefixes; scope its policy as in `docs/github-oidc-role.md`.)
- **Locking:** S3-native (`use_lockfile = true`, Terraform ≥ 1.10): Terraform writes `<key>.tflock` with a conditional write, so two concurrent runs can't both hold it. **No DynamoDB table is needed.**
- **Partial backend config:** `backend.tf` holds the key; `bucket` and `region` are passed with `-backend-config` so the account ID is never committed.
- **Chicken-and-egg:** `bootstrap/` creates the bucket using *local* state, then everything else uses the bucket.
- **If the bucket is deleted:** versioning lets you restore deleted state objects (undelete the delete markers) while the bucket exists. If the bucket itself is gone, state is lost: recreate the bucket (`bootstrap`), then `terraform import` each resource, or destroy leftovers by tag (`ManagedBy=terraform`). `prevent_destroy` guards against accidental `terraform destroy` of the bootstrap.

## 7. GitHub Actions pipeline
- **Pull request** → `validate` job (fmt -check, backend-less init + validate for both envs, module tests) → `plan` dev and prod using the `GitHub-OIDC` role. Plans appear in the run summary. Nothing is applied.
- **Push to `main`** → validate → plan dev → **apply dev** (environment `dev`) → plan prod → **apply prod** (environment `prod`, pauses for approval). Apply uses the exact saved plan file.
- Least-privilege `permissions` (`contents: read`, `id-token: write` only on AWS jobs); apply jobs are serialised per environment and never cancelled mid-run.

## 8. GitHub OIDC
The OIDC provider (`token.actions.githubusercontent.com`, audience `sts.amazonaws.com`) and the IAM role `arn:aws:iam::868713841842:role/GitHub-OIDC` **already exist and are managed outside this repository**. Terraform here never creates, changes or replaces them.

1. Workflows request an OIDC token (`permissions: id-token: write`) and call `aws-actions/configure-aws-credentials@v4` with `role-to-assume: arn:aws:iam::868713841842:role/GitHub-OIDC`, `aws-region: us-east-1`. No AWS keys or tokens are stored in GitHub.
2. Dev and prod share this one role.
3. **The role's trust policy must allow four subjects**, not just `ref:refs/heads/main`: `pull_request`, `ref:refs/heads/main`, `environment:dev` and `environment:prod`. A job with `environment:` (needed for the prod approval gate) sends the `environment:` subject instead of the branch subject, so a `main`-only trust policy would make the apply jobs fail with `AssumeRoleWithWebIdentity` errors. The exact JSON, required permissions and the security trade-off of a shared role are in [docs/github-oidc-role.md](docs/github-oidc-role.md). **The real role's policies have not been inspected yet** (no valid AWS credentials were available).

## 9. Required AWS / GitHub configuration
**AWS:**
1. Verify the existing role's trust policy and permissions against [docs/github-oidc-role.md](docs/github-oidc-role.md) and update the role if needed (your change; this repo doesn't touch it).
2. Create the state bucket once (S3 only, no IAM/OIDC):
```bash
aws sts get-caller-identity            # must show account 868713841842
scripts/bootstrap-state.sh
```
**GitHub:** no repository variables or secrets are required. Role ARN, region and the state bucket name (`foundation-tfstate-868713841842`, produced by the bootstrap) are set in `.github/workflows/terraform-env.yml`; none are secret.

**Environments / approval gate** (Settings → Environments):
1. Create `dev` (no protection).
2. Create `prod` → enable **Required reviewers** (add yourself/your team) and restrict **Deployment branches** to `main`. This is what pauses the pipeline before prod apply.
3. Optional: branch protection on `main` requiring the `terraform` checks.

## 10. Run Terraform locally
Needs AWS credentials for the target account (any method; never commit them) and Terraform ≥ 1.10.
```bash
BUCKET=$(terraform -chdir=bootstrap output -raw state_bucket_name)   # or your bucket name

# plan DEV
cd environments/dev
terraform init -backend-config="bucket=$BUCKET" -backend-config="region=us-east-1"
terraform plan

# plan PROD
cd ../prod
terraform init -backend-config="bucket=$BUCKET" -backend-config="region=us-east-1"
terraform plan

# deploy (normally done by the pipeline)
terraform apply            # run in the environment directory
```
Offline checks (no AWS): `terraform fmt -check -recursive`, `terraform init -backend=false && terraform validate`, `terraform test` inside `modules/vpc|security-groups|foundation`.

## 11. Destroy safely
1. Confirm the directory and account: `pwd`, `aws sts get-caller-identity`.
2. `cd environments/dev && terraform init ... && terraform plan -destroy` — read it.
3. `terraform destroy`. Do **dev first**; do prod only deliberately (nothing else is in these VPCs; if you later add workloads, remove them first or destroy fails on dependent ENIs).
4. Destroy the bootstrap last (it has `prevent_destroy`; empty the versioned bucket and remove that lifecycle line deliberately).
There is intentionally no destroy workflow.

## 12. Security considerations
See [SECURITY.md](SECURITY.md): OIDC with repo/environment-pinned roles, separate dev/prod roles, state encryption/versioning/public block, closed-by-default security groups, isolated DB subnets, and an honest list of known limitations.

## 13. Cost considerations (us-east-1, approximate, verify current pricing)
- **NAT Gateway ≈ $0.045/hour (~$33/month) each, plus $0.045/GB processed.** dev has 1, prod has 2 → roughly **$100/month for NAT alone if left running.**
- Elastic IPs attached to NATs are free while in use (public IPv4 addresses are billed hourly when idle).
- Flow logs: CloudWatch ingestion/storage, small at low traffic. S3 endpoint, VPC, subnets, routes, SGs, IAM: free. State bucket: pennies.
- **To keep a portfolio run cheap, apply, verify, then destroy.**

## 14. Production considerations
Ready: modular design, remote state with locking, OIDC, approval gate, tests. Further hardening for a larger organisation: separate read-only plan and per-environment apply roles instead of one shared role (see `docs/github-oidc-role.md`), one AWS account per environment, a permissions boundary on the deploy role, KMS CMKs for state/logs, state-bucket access logging and replication, SHA-pinned Actions, policy-as-code (tflint/tfsec/checkov in CI), drift detection, alarms on flow logs/NAT, VPC interface endpoints instead of NAT for AWS APIs.

## 15. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Trust `sub` mismatch. Most likely the trust policy only allows `ref:refs/heads/main` while the job runs with `environment:` (sub = `...:environment:prod`) or on a pull request (`...:pull_request`). Add the four subjects in `docs/github-oidc-role.md`. |
| `Credentials could not be loaded` in Actions | Missing `permissions: id-token: write` on the job (or on the caller of the reusable workflow). |
| `AccessDenied` for an `s3:`/`ec2:`/`logs:`/`iam:` action | The permission policy of the `GitHub-OIDC` role lacks that action (see `docs/github-oidc-role.md`). Update the role; it is not managed here. |
| `Error acquiring the state lock` | Another run holds `<key>.tflock`; wait, or after confirming nothing is running `terraform force-unlock <id>`. |
| `Backend configuration changed` / bucket empty | `terraform init` without `-backend-config`, or wrong bucket. Pass bucket and region. |
| `BucketAlreadyOwnedByYou` in bootstrap | The state bucket already exists; import it (`terraform import aws_s3_bucket.state <name>`) instead of recreating. |
| `The security token included in the request is invalid` locally | Stale/invalid local AWS credentials; run `aws sts get-caller-identity` and fix the profile. |
| `Unsupported argument use_lockfile` | Terraform < 1.10. Upgrade. |

## 16. Verification results
Recorded 2026-10-06 on Terraform 1.16.2, AWS provider 6.67.0 (locked), Windows 11. Only what was actually executed is marked PASS.

| Check | Result |
|---|---|
| `terraform fmt -check -recursive` | PASS |
| `terraform init -backend=false` + `validate`: `environments/dev`, `environments/prod`, `modules/foundation`, `bootstrap` | PASS (all four) |
| `terraform test` (mocked provider): vpc 5/5, security-groups 4/4, foundation 3/3 | PASS (12/12) |
| Provider lock files (linux_amd64, windows_amd64, darwin_arm64, darwin_amd64) for dev, prod, bootstrap | PASS |
| `terraform plan` against AWS (dev/prod) | **NOT RUN**: the AWS credentials available locally were rejected (`InvalidClientTokenId`) and the state bucket does not exist yet |
| Bootstrap apply (state bucket) | **NOT RUN**: needs valid AWS credentials |
| Existing `GitHub-OIDC` role trust/permissions inspected | **NOT DONE**: `aws iam get-role` failed with `InvalidClientTokenId`. Requirements are documented in `docs/github-oidc-role.md`; the real role must be compared against them |
| AWS resource verification (VPC, subnets, NAT, SGs, roles, tags) | **NOT DONE**: nothing has been deployed |
| GitHub Actions run | **NOT RUN**: workflows are committed but have never executed; their YAML was reviewed by hand, not machine-validated (no YAML linter available locally) |
| GitHub Environments / approval gate | **NOT CONFIGURED**: manual steps in §9 |
| tflint / tfsec / checkov | **NOT RUN**: not installed (not installed automatically) |

Expected first-run work: the trust policy likely needs the `environment:` and `pull_request` subjects, and the role's permissions have never been exercised with this Terraform (see Troubleshooting).
