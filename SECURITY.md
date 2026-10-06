# Security model

## Reporting
Open a private security advisory on the repository (Security tab > Report a vulnerability). Do not post secrets or exploits in public issues.

## Authentication: GitHub OIDC, no stored keys
GitHub Actions exchanges a short-lived OIDC token for temporary AWS credentials (`aws-actions/configure-aws-credentials@v4`). **No `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` or `AWS_SESSION_TOKEN` exist anywhere in GitHub or in this repository.**

The OIDC provider and the role `arn:aws:iam::868713841842:role/GitHub-OIDC` were created manually and are an **external dependency**; this repository does not create or manage them. Dev and prod share that role. Requirements for its trust policy (exact repository, `aud = sts.amazonaws.com`, the four allowed `sub` values) and permissions are in [docs/github-oidc-role.md](docs/github-oidc-role.md). The real role has not yet been inspected from this project.

## Shared-role risk (important)
Because one role serves pull-request plans and production applies, anything that can obtain a `pull_request` token for this repository (anyone who can open a PR from a branch in it) can run Terraform with that role's permissions, including via a modified workflow. The prod approval gate protects `environment: prod` jobs, not an arbitrary PR job using the same role. Recommended: split into a read-only plan role and environment-scoped apply roles, and meanwhile restrict who can open PRs and require approval for workflow runs.

## Terraform state
- One S3 bucket, `foundation-tfstate-<account-id>`: SSE-S3 encryption, versioning, all public access blocked, ACLs disabled (`BucketOwnerEnforced`), TLS-only bucket policy, `prevent_destroy`.
- Separate keys: `dev/terraform.tfstate`, `prod/terraform.tfstate`; S3-native locking.
- State is never stored in Git (`.gitignore` blocks `*.tfstate*`, `*.tfvars`, plan files).

## Network
- Private app/db subnets; DB subnets have no default route at all.
- Security groups chain web -> app -> db by security-group reference. The web tier has **no ingress by default**; `0.0.0.0/0` needs `allow_public_web_ingress = true` and is rejected in the CIDR list by validation.
- The default VPC security group is emptied. VPC flow logs go to CloudWatch.
- The only broad rule is app egress 443 to `0.0.0.0/0` through NAT (no stable destination CIDRs); documented in code.

## Known limitations (hardening for a larger organization)
- Shared plan/apply role (above); no permissions boundary.
- State and flow logs use AWS-managed encryption (SSE-S3 / CloudWatch default), not customer-managed KMS keys.
- Third-party Actions are pinned to major version tags, not commit SHAs.
- No state-bucket access logging, no cross-region replication, no SCPs, no GuardDuty/Config.
- Never run against a live account yet; expect to adjust role permissions on first apply.
