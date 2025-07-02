#!/bin/bash
set -e

usage() {
  echo "Usage: $0 --profile <aws_profile> --region <aws_region>"
  echo "  --profile   AWS CLI profile name (optional, default: default)"
  echo "  --region    AWS region (required)"
  echo "  -h, --help  Show this help message"
}

# Parse arguments
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

# Check for AWS CLI
if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI not found. Please install it first." >&2
  exit 1
fi

# Check for jq (optional, but useful for parsing JSON)
if ! command -v jq >/dev/null 2>&1; then
  echo "Warning: jq not found. JSON parsing will be limited." >&2
fi

# 1. Deploy the parent stack (create or update)
if aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation describe-stacks --stack-name ecs-parent >/dev/null 2>&1; then
  echo "Updating parent stack..."
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation update-stack --stack-name ecs-parent \
    --template-body file://base.json \
    --capabilities CAPABILITY_NAMED_IAM || true
else
  echo "Creating parent stack..."
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation create-stack --stack-name ecs-parent \
    --template-body file://base.json \
    --capabilities CAPABILITY_NAMED_IAM
fi

echo "Waiting for parent stack to complete..."
aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation wait stack-create-complete --stack-name ecs-parent

# 2. Get outputs from parent stack
gen_output() {
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation describe-stacks --stack-name ecs-parent \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

VPC=$(gen_output VPC)
SUBNET1=$(gen_output Subnet1)
SUBNET2=$(gen_output Subnet2)
ECSCLUSTER=$(gen_output ECSCluster)
ECRREPO=$(gen_output ECRRepo)
LOGGROUP=$(gen_output LogGroup)
TASKROLE=$(gen_output ECSTaskExecutionRole)
SG=$(gen_output ECSSecurityGroup)

# 3. Define app configs as arrays for easier management
APPS=(app1 app2 app6)
# APPS=(app1 app2 app3 app4 app5 app6)
IMAGES=(nginx:latest httpd:latest)
ENVS=(value1 value2 value6)
TEMPLATES=(app1.json app2.json app6.json)

# 4. Deploy each child stack (create or update)
for idx in ${!APPS[@]}; do
  APP="${APPS[$idx]}"
  TEMPLATE="${TEMPLATES[$idx]}"
  STACK_NAME="ecs-$APP"

  if [ "$APP" == "app6" ]; then
    IMAGE="$ECRREPO:app6-latest"
    ENV="value6"
  else
    IMAGE="${IMAGES[$idx]}"
    ENV="${ENVS[$idx]}"
  fi

  if aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation describe-stacks --stack-name $STACK_NAME >/dev/null 2>&1; then
    echo "Updating child stack $STACK_NAME..."
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation update-stack --stack-name $STACK_NAME \
      --template-body file://$TEMPLATE \
      --parameters \
        ParameterKey=VPC,ParameterValue=$VPC \
        ParameterKey=Subnet1,ParameterValue=$SUBNET1 \
        ParameterKey=Subnet2,ParameterValue=$SUBNET2 \
        ParameterKey=ECSCluster,ParameterValue=$ECSCLUSTER \
        ParameterKey=ECRRepo,ParameterValue=$ECRREPO \
        ParameterKey=LogGroup,ParameterValue=$LOGGROUP \
        ParameterKey=ECSTaskExecutionRole,ParameterValue=$TASKROLE \
        ParameterKey=ECSSecurityGroup,ParameterValue=$SG \
        ParameterKey=AppImage,ParameterValue=$IMAGE \
        ParameterKey=AppName,ParameterValue=$APP \
        ParameterKey=EnvVar1,ParameterValue=$ENV || true
  else
    echo "Creating child stack $STACK_NAME..."
    aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation create-stack --stack-name $STACK_NAME \
      --template-body file://$TEMPLATE \
      --parameters \
        ParameterKey=VPC,ParameterValue=$VPC \
        ParameterKey=Subnet1,ParameterValue=$SUBNET1 \
        ParameterKey=Subnet2,ParameterValue=$SUBNET2 \
        ParameterKey=ECSCluster,ParameterValue=$ECSCLUSTER \
        ParameterKey=ECRRepo,ParameterValue=$ECRREPO \
        ParameterKey=LogGroup,ParameterValue=$LOGGROUP \
        ParameterKey=ECSTaskExecutionRole,ParameterValue=$TASKROLE \
        ParameterKey=ECSSecurityGroup,ParameterValue=$SG \
        ParameterKey=AppImage,ParameterValue=$IMAGE \
        ParameterKey=AppName,ParameterValue=$APP \
        ParameterKey=EnvVar1,ParameterValue=$ENV
  fi

  echo "Waiting for child stack $STACK_NAME to complete..."
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" cloudformation wait stack-create-complete --stack-name $STACK_NAME || {
    echo "Error: Stack $STACK_NAME failed to deploy." >&2
    exit 1
  }
done

echo "All stacks deployed!"