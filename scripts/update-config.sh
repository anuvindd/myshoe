#!/bin/bash
set -e
# Update kubernetes manifests with live terraform outputs
TERRAFORM_DIR="$(dirname "$0")/../terraform"
if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then echo "Run terraform apply first"; exit 1; fi
RDS_ENDPOINT=$(terraform -chdir="$TERRAFORM_DIR" output -raw rds_endpoint 2>/dev/null | cut -d: -f1)
RDS_PWD=$(grep db_password "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
ECR_URL=$(terraform -chdir="$TERRAFORM_DIR" output -raw ecr_repo_url 2>/dev/null)

echo "RDS: $RDS_ENDPOINT"
echo "ECR: $ECR_URL"

# Patch configmap
sed -i "s|DB_HOST:.*|DB_HOST: \"$RDS_ENDPOINT\"|" kubernetes/configmap-secret.yaml || true
# Patch deployment image
sed -i "s|image:.*myshoe-app.*|image: $ECR_URL:latest|" kubernetes/app.yaml || true

echo "Patched. Now: kubectl create secret generic myshoe-secret --from-literal=DB_PASSWORD=$RDS_PWD --dry-run=client -o yaml | kubectl apply -f -"
