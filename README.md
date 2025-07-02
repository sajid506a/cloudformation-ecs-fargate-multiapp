# CloudFormation ECS Fargate Multi-App Deployment

This project provisions an AWS ECS Fargate environment and deploys five sample applications as separate CloudFormation child stacks. It is designed for easy extension and automation.

## Project Structure

- `base.json` - Parent stack template. Provisions VPC, subnets, ECS cluster, ECR repo, CloudWatch log group, IAM roles, and security group.
- `app1.json` to `app5.json` - Child stack templates. Each defines an ECS Fargate service and task definition for a specific app (nginx, httpd, redis, node, amazonlinux).
- `deploy.sh` - Bash script to deploy the parent stack and all child stacks. Handles stack creation/update, parameter passing, and waits for completion.

## Prerequisites

- AWS CLI installed and configured.
- Bash shell (Linux, macOS, or Windows with WSL/Git Bash).
- (Optional) `jq` for improved JSON parsing.

## Usage

Run the deployment script with the required AWS region. The AWS CLI profile is optional (defaults to `default`).

```
bash deploy.sh --region <aws-region> [--profile <aws-profile>]
```

- `--region`   : AWS region to deploy resources (required)
- `--profile`  : AWS CLI profile to use (optional, default: `default`)
- `-h, --help` : Show help message

### Example

```
bash deploy.sh --region us-east-1 --profile my-aws-profile
bash deploy.sh --region us-east-1
# or
bash deploy.sh --profile default --region us-east-1
```

## How It Works

1. **Parent Stack** (`base.json`):
   - Provisions networking (VPC, subnets, route tables, IGW), ECS cluster, ECR repo, CloudWatch log group, IAM role, and security group.
   - Outputs all resource IDs for use by child stacks.
2. **Child Stacks** (`app1.json` ... `app5.json`):
   - Each defines an ECS Fargate service and task definition for a specific app image.
   - Parameters are passed from the parent stack outputs and script arrays.
3. **Script** (`deploy.sh`):
   - Deploys or updates the parent stack.
   - Waits for completion, then fetches outputs.
   - Iterates over each app, deploying or updating the child stack with the correct parameters.
   - Waits for each child stack to complete.

## Customization

- To add/remove apps, edit the `APPS`, `IMAGES`, `ENVS`, and `TEMPLATES` arrays in `deploy.sh`.
- Modify the CloudFormation templates as needed for your application requirements.

## Notes

- The script is idempotent: it will update stacks if they already exist.
- If a stack deployment fails, the script will exit with an error.
- All AWS CLI commands use the specified profile and region.

## License

MIT License

### Deleting All Stacks

To delete all child and parent stacks created by this project, use the provided script:

```
bash delete.sh --region <aws-region> [--profile <aws-profile>]
```

- `--region`   : AWS region where stacks were deployed (required)
- `--profile`  : AWS CLI profile to use (optional, default: `default`)
- `-h, --help` : Show help message

This will delete all `ecs-app1` to `ecs-app5` child stacks first, then the `ecs-parent` stack.
