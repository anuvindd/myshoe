# MyShoe — Shoe Brand E-Commerce on AWS

Live: `myshoe.sytes.net` → `myshoe-app-alb-1194032437.ap-south-1.elb.amazonaws.com` (ALB, ap-south-1)

## Quick start (after infra apply)
See `docs/deployment-guide.md` for the full 10-step flow.

## Repo layout
```
terraform/          # VPC, EC2, RDS, ALB, S3, ECR, IAM
docker/app/         # Flask + MySQL e-commerce app
docker/             # Dockerfile, compose, requirements
kubernetes/         # Deployment/Service/HPA/Ingress/PVC/ConfigMap/Secret
ansible/            # playbook + aws_ec2 dynamic inventory
.github/workflows/  # ci.yml, cd.yml
monitoring/         # Prometheus + Grafana
docs/               # proposal, architecture, network, deployment-guide
scripts/            # update-config.sh
```

## Infra outputs (current deploy)
- VPC vpc-0ce837376db8c25be 10.0.0.0/16
- Master 15.207.57.86 / Workers 15.252.54.155, 13.207.231.99
- RDS myshoe (db.t3.micro, encrypted)
- ALB myshoe-app-alb-1194032437.ap-south-1.elb.amazonaws.com
- ECR 470999030662.dkr.ecr.ap-south-1.amazonaws.com/myshoe-app
- S3 myshoe-assets-470999030662

## Deliverables checklist
- [x] Proposal (docs/proposal.md)
- [x] Architecture diagram (docs/architecture.md)
- [x] Network diagram (docs/network.md)
- [x] Terraform IaC
- [x] Ansible playbook + inventory
- [x] Docker + compose + ECR
- [x] K8s manifests + HPA
- [x] CI/CD (GitHub Actions)
- [x] Monitoring (Prometheus/Grafana)
- [x] Deployment docs
- [ ] Presentation + demo video — record a 3-min walkthrough: `curl` the ALB, show K8s pods, Grafana at :3000

## Security notes
- Secrets in `terraform.tfvars` (gitignored) and K8s Secret; never commit `.pem`
- Least-privilege SGs; restrict 22 to your IP in production: `aws ec2 authorize-security-group-ingress --group-id <k8s-sg> --protocol tcp --port 22 --cidr $(curl -s https://checkip.amazonaws.com)/32`
- Next: ACM cert at sytes.net for HTTPS, close 0.0.0.0/0 on 6443
