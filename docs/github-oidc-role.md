# Existing GitHub OIDC role (external dependency)

This repository **does not create or manage** the OIDC provider or the role. They were created manually and are treated as an external dependency:

| Item | Value |
|---|---|
| OIDC provider | `token.actions.githubusercontent.com` |
| Audience | `sts.amazonaws.com` |
| Role ARN | `arn:aws:iam::868713841842:role/GitHub-OIDC` |
| Repository | `sabo1166/CICD-terraform-project-2-env` |

Both `dev` and `prod` use this one role (as requested). The trade-off is in "Security trade-off" below.

## Status of verification
The trust and permission policies of the real role **have not been inspected**: the AWS credentials available when this was written were rejected (`InvalidClientTokenId`). Compare the real role with the requirements below; do not assume it matches.

Check it yourself:
```bash
aws iam get-role --role-name GitHub-OIDC --query 'Role.AssumeRolePolicyDocument'
aws iam list-attached-role-policies --role-name GitHub-OIDC
aws iam list-role-policies --role-name GitHub-OIDC
```

## Trust policy the pipeline needs
The OIDC `sub` claim depends on how the job runs:

| Workflow job | `sub` sent by GitHub |
|---|---|
| plan on a pull request | `repo:sabo1166/CICD-terraform-project-2-env:pull_request` |
| plan on push to `main` | `repo:sabo1166/CICD-terraform-project-2-env:ref:refs/heads/main` |
| apply dev (job has `environment: dev`) | `repo:sabo1166/CICD-terraform-project-2-env:environment:dev` |
| apply prod (job has `environment: prod`) | `repo:sabo1166/CICD-terraform-project-2-env:environment:prod` |

**Important:** a job that declares `environment:` sends the `environment:` subject and **not** `ref:refs/heads/main`. A trust policy that only allows `ref:refs/heads/main` will therefore reject the apply jobs (and the pull-request plans). To keep the prod approval gate, the trust policy needs all four subjects:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::868713841842:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": [
            "repo:sabo1166/CICD-terraform-project-2-env:pull_request",
            "repo:sabo1166/CICD-terraform-project-2-env:ref:refs/heads/main",
            "repo:sabo1166/CICD-terraform-project-2-env:environment:dev",
            "repo:sabo1166/CICD-terraform-project-2-env:environment:prod"
          ]
        }
      }
    }
  ]
}
```

Use `StringEquals` with exact subjects, never `repo:sabo1166/*` or a wildcard on the repository. It is too broad if the existing policy allows other repositories, other branches, or no `sub` condition at all; in that case tighten it to the above.

## Permissions the role needs
Trust only controls *who* can assume the role; the role's permissions control what Terraform can do. At minimum (account `868713841842`, region `us-east-1`, state bucket `foundation-tfstate-868713841842`):

- **State:** `s3:ListBucket` on the bucket; `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on `dev/*` and `prod/*` (the `.tflock` lock files are objects under those prefixes).
- **Network:** `ec2:Describe*`, and Create/Delete/Modify/Attach/Detach/Associate for VPCs, subnets, internet gateways, NAT gateways, addresses, route tables and routes, security groups and their rules, VPC endpoints, flow logs, and tags.
- **Logs:** create/delete/tag log groups under `/foundation/*`, `logs:PutRetentionPolicy`, `logs:DescribeLogGroups`, and the `logs:*LogDelivery` actions used for flow logs.
- **IAM:** create/delete/tag/pass the roles named `foundation-dev-*` and `foundation-prod-*` (the VPC flow-log delivery role), with `iam:PassedToService = vpc-flow-logs.amazonaws.com` on `iam:PassRole`.

Anything broader (for example `AdministratorAccess`) will work but is not least privilege; see below.

## Security trade-off of one shared role
- Pull-request plans and production applies use the same role. If `pull_request` is in the trust policy, anyone who can open a pull request in this repository can run Terraform with that role's permissions from their branch, including a modified workflow, and the prod approval gate does not stop that. With a read-only role this is acceptable; with an apply-capable role it is not.
- Recommended (not done, because you asked for no new roles): a separate read-only role for plan (trusted for `pull_request` and `main`) and one apply role trusted only for `environment:dev` / `environment:prod`, ideally one per environment. The pipeline can adopt this by changing only the `role-to-assume` lines in `.github/workflows/terraform-env.yml`.
- Mitigations available without new roles: remove `pull_request` from the trust policy (then PR plans will fail to authenticate), restrict who can open PRs / require approval for workflow runs, protect `main` with required reviews, and restrict the `prod` environment to the `main` branch.
