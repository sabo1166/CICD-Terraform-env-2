# Contributing

1. Branch from `main`; never push to `main` directly.
2. Before opening a pull request:
   ```bash
   terraform fmt -recursive
   for m in vpc security-groups foundation; do (cd modules/$m && terraform init -backend=false && terraform test); done
   for e in dev prod; do (cd environments/$e && terraform init -backend=false && terraform validate); done
   ```
3. The PR pipeline runs fmt, validate, module tests and a real `plan` for **both** dev and prod. Read both plans.
4. Merging to `main` applies dev automatically and prod after approval.
5. Never commit `.tfstate`, `.tfvars` (only `*.tfvars.example`), credentials or tokens.
6. Put new infrastructure in a module under `modules/` and call it from `modules/foundation`; do not copy resources between environments.
7. Comments explain *why*, not *what*.
