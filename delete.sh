#!/bin/bash
set -e

usage() {
  echo "Usage: $0 --region <aws_region> [--profile <aws_profile>]"
  echo "  --profile   AWS CLI profile name (optional, default: default)"
  echo "  --region    AWS region (required)"
  echo "  -h, --help  Show this help message"
}

AWS_PROFILE="default"
while [[ $# -gt 0 ]]; do
  case $1 in
    --profile)
      AWS_PROFILE="$2"
      shift 2
      ;;
    --region)
      AWS_REGION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$AWS_REGION" ]; then
  echo "Error: --region argument is required." >&2
  usage
  exit 1
fi

# Delete child stacks first
for APP in app1 app2 app3 app4 app5; do
  STACK_NAME="ecs-$APP"
  if aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation describe-stacks --stack-name $STACK_NAME >/dev/null 2>&1; then
    echo "Deleting child stack $STACK_NAME..."
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation delete-stack --stack-name $STACK_NAME
    echo "Waiting for child stack $STACK_NAME to be deleted..."
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation wait stack-delete-complete --stack-name $STACK_NAME
  else
    echo "Child stack $STACK_NAME does not exist, skipping."
  fi
done

# Delete parent stack
if aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation describe-stacks --stack-name ecs-parent >/dev/null 2>&1; then
  echo "Deleting parent stack ecs-parent..."
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation delete-stack --stack-name ecs-parent
  echo "Waiting for parent stack ecs-parent to be deleted..."
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation wait stack-delete-complete --stack-name ecs-parent
else
  echo "Parent stack ecs-parent does not exist, skipping."
fi

echo "All stacks deleted!"
