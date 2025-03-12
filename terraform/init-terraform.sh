#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Check if both arguments are provided
if [ $# -lt 2 ]; then
  echo "Usage: $0 <state_key> <apply|destroy>"
  echo "Example: $0 dev/terraform.tfstate apply"
  exit 1
fi

# Assign the provided arguments to variables
KEY=$1
OPERATION=$2

# Validate operation type
if [ "$OPERATION" != "apply" ] && [ "$OPERATION" != "destroy" ]; then
  echo "Error: Operation must be either 'apply' or 'destroy'"
  exit 1
fi

# Navigate to the bootstrap directory to capture output values
cd bootstrap

# Capture the output values from the bootstrap configuration
BUCKET=$(terraform output -raw state_bucket_name)
REGION=$(terraform output -raw region)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)
ECR_ACCESS_ROLE_ARN=$(terraform output -raw apprunner_ecr_access_role_arn)

# Return to the root directory
cd ..

# Display the values being used (for transparency and debugging)
echo "Using bucket: $BUCKET"
echo "Using region: $REGION"
echo "Using dynamodb_table: $DYNAMODB_TABLE"
echo "Using key: $KEY"
echo "Using App Runner ECR access role ARN: $ECR_ACCESS_ROLE_ARN"
echo "Operation: $OPERATION"

# Initialize Terraform with the backend configuration using -reconfigure
terraform init -reconfigure \
  -backend-config="bucket=$BUCKET" \
  -backend-config="region=$REGION" \
  -backend-config="dynamodb_table=$DYNAMODB_TABLE" \
  -backend-config="key=$KEY"

if [ "$OPERATION" == "apply" ]; then
  # Apply operation - first specific targets, then everything
  echo "Step 1: Applying App Runner service and custom domain association..."
  terraform apply -target=aws_apprunner_service.example -target=aws_apprunner_custom_domain_association.example -auto-approve -var="apprunner_ecr_access_role_arn=$ECR_ACCESS_ROLE_ARN"

  echo "Step 2: Applying the full configuration..."
  terraform apply -auto-approve -var="apprunner_ecr_access_role_arn=$ECR_ACCESS_ROLE_ARN"
else
  # Destroy operation - single step to destroy everything
  echo "Destroying all resources..."
  terraform destroy -auto-approve -var="apprunner_ecr_access_role_arn=$ECR_ACCESS_ROLE_ARN"
fi
echo "Operation '$OPERATION' completed successfully"