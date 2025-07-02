# CloudFormation ECS Fargate Multi-App Deployment (CI/CD)

This project provisions an AWS ECS Fargate environment and deploys up to five sample applications as separate CloudFormation child stacks. It is designed for robust, idempotent, and automated multi-app deployment using a CI/CD pipeline.

## Project Structure

- `base.json` - Parent stack template. Provisions VPC, subnets, ECS cluster, ECR repo, CloudWatch log group, IAM roles, and security group.
- `app1.json` to `app5.json` - Child stack templates. Each defines an ECS Fargate service and task definition for a specific app (nginx, httpd, redis, node, amazonlinux). Each child stack always creates a unique CloudWatch log group for ECS logging.
- `.github/workflows/deploy.yml` - GitHub Actions workflow for CI/CD: builds, versions, and deploys Docker images and CloudFormation stacks.
- `.gitignore` - Standard ignore patterns for AWS, OS, and development artifacts.

## Prerequisites

- AWS CLI and Docker installed on CI/CD runners (for local testing, install both on your machine).
- AWS ECR repository created for storing Docker images for each app (e.g., one repo per app, or a single repo with different tags).
- GitHub repository secrets set: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and (optionally) `AWS_REGION` and your ECR repo URI as a secret or workflow variable.

## Usage (CI/CD)

On every push to `main`, the workflow will:
1. Build and tag Docker images for each app (e.g., `app1:<sha>`).
2. Push images to ECR.
3. Deploy or update CloudFormation stacks, passing the new image tag as a parameter.

You can also trigger the workflow manually from the GitHub Actions tab.

## How It Works

1. **Docker Build & Push**:
   - Each app's Docker image is built and tagged with the commit SHA.
   - Images are pushed to ECR.
2. **CloudFormation Deploy**:
   - Each child stack is updated with the new image tag using the `AppImage` parameter.
   - Uses `aws cloudformation deploy` for idempotent updates.

## Customization

- To add/remove apps, update the workflow and CloudFormation templates accordingly.
- Modify the CloudFormation templates as needed for your application requirements.

## Notes

- Each app stack always creates a new CloudWatch log group for ECS logging, ensuring no name conflicts.
- All AWS CLI commands use the specified profile and region from the workflow environment.
- The workflow is idempotent: it will update stacks if they already exist.

## Deleting All Stacks

To delete all child and parent stacks, you can use the AWS CLI or create a similar workflow/script for teardown.

## License

MIT License
