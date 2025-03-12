#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Check if the key argument is provided
if [ -z "$1" ]; then
  echo "Please provide the state key"
  exit 1
fi

# Assign the provided key to a variable
KEY=$1

# Navigate to the bootstrap directory to capture output values
cd bootstrap

# Capture the output values from the bootstrap configuration
BUCKET=$(terraform output -raw state_bucket_name)
REGION=$(terraform output -raw region)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)

# Return to the root directory
cd ..

# Display the values being used (for transparency and debugging)
echo "Using bucket: $BUCKET"
echo "Using region: $REGION"
echo "Using dynamodb_table: $DYNAMODB_TABLE"
echo "Using key: $KEY"

# Initialize Terraform with the backend configuration using -reconfigure
terraform init -reconfigure \
  -backend-config="bucket=$BUCKET" \
  -backend-config="region=$REGION" \
  -backend-config="dynamodb_table=$DYNAMODB_TABLE" \
  -backend-config="key=$KEY"

# Step 1: Apply the App Runner service and custom domain association
echo "Step 1: Applying App Runner service and custom domain association..."
terraform apply -target=aws_apprunner_service.example -target=aws_apprunner_custom_domain_association.example -auto-approve

# Step 2: Apply the full configuration
echo "Step 2: Applying the full configuration..."
terraform apply -auto-approve