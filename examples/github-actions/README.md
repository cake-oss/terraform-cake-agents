# GitHub Actions deploy role example

Provisions a GitHub OIDC provider and an IAM role that GitHub Actions can assume to apply the root module.

## Usage

Apply this example as an admin (one-time), then point your workflow at the resulting role.

```bash
terraform init
terraform apply -var name=prod -var github_org=your-org -var github_repo=your-repo
```

Add the `role_arn` output to your workflow:

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT_ID:role/prod-deploy
          aws-region: us-east-2
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init && terraform apply -auto-approve
```

The role trusts any workflow in `<github_org>/<github_repo>`. To restrict further (specific branches, environments), edit `assume_role_conditions` in `main.tf` — for example `repo:org/repo:ref:refs/heads/main` or `repo:org/repo:environment:production`.
