# Security model

## Reporting
Open a private security advisory on the repository (Security tab > Report a vulnerability). Do not post secrets or exploits in public issues.

## Authentication: GitHub OIDC, no stored keys
GitHub Actions exchanges a short-lived OIDC token for temporary AWS credentials (`aws-actions/configure-aws-credentials`). **No `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` exist anywhere in GitHub.** The only repository/environment *variables* are non-secret identifiers (role ARNs, bucket name, region).

| Role | Assumed by (OIDC `sub`) | Can do |
|---|---|---|
| `foundation-github-plan` | `repo:sabo1166/CICD-terraform-project-2-env:pull_request` and `:ref:refs/heads/main` | Read-only describe calls; read state; create/delete only `*/terraform.tfstate.tflock` |
| `foundation-github-apply-dev` | `repo:sabo1166/CICD-terraform-project-2-env:environment:dev` | Manage dev network resources, `dev/*` state only |
| `foundation-github-apply-prod` | `repo:sabo1166/CICD-terraform-project-2-env:environment:prod` | Manage prod network resources, `prod/*` state only |

Every trust policy pins the audience (`sts.amazonaws.com`) and the exact repository. The prod role can only be assumed by a job running in the `prod` GitHub Environment, i.e. after required reviewers approved it. A compromised dev job cannot touch prod state or resources. Pull requests from forks receive no OIDC token.

## Terraform state
- One S3 bucket, `foundation-tfstate-<account-id>`: SSE-S3 encryption, versioning, all public access blocked, ACLs disabled (`BucketOwnerEnforced`), TLS-only bucket policy, `prevent_destroy`.
- Separate keys: `dev/terraform.tfstate`, `prod/terraform.tfstate`. Apply roles are limited to their own prefix.
- State is never stored in Git (`.gitignore` blocks `*.tfstate*`, `*.tfvars`, plan files).

## Network
- Private app/db subnets; DB subnets have no default route at all.
- Security groups chain web -> app -> db by security-group reference. The web tier has **no ingress by default**; `0.0.0.0/0` needs `allow_public_web_ingress = true` and is rejected in the CIDR list by validation.
- The default VPC security group is emptied. VPC flow logs go to CloudWatch.
- The only broad rule is app egress 443 to `0.0.0.0/0` through NAT (no stable destination CIDRs); documented in code.

## Known limitations (hardening for a larger organization)
- The apply roles can create IAM roles/inline policies named `foundation-<env>-*`, which is a privilege-escalation path. Add a permissions boundary or move IAM changes to a separate pipeline.
- State and flow logs use AWS-managed encryption (SSE-S3 / CloudWatch default), not customer-managed KMS keys.
- Third-party Actions are pinned to major version tags, not commit SHAs.
- No state-bucket access logging, no cross-region replication, no SCPs, no GuardDuty/Config.
- Role permissions were written from the Terraform provider's API usage and have **not** been exercised against a live account yet; expect to add a missing action on first apply.
