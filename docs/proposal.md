# MyShoe — Cloud & DevOps Capstone Proposal

**Project:** Shoe brand e-commerce platform on AWS (ap-south-1)
**Domain:** myshoe.sytes.net → ALB `myshoe-app-alb-1194032437.ap-south-1.elb.amazonaws.com`
**Stack:** Flask + MySQL (RDS) + Docker + Kubernetes (self-managed on EC2 via kubeadm) + Terraform + Ansible + GitHub Actions + Prometheus/Grafana + ALB

## 1. Objective
Build a secure, scalable, automated, highly-available shoe store that demonstrates all 7 capstone phases: Linux admin, Ansible automation, AWS cloud, CI/CD, Docker, Kubernetes, Terraform IaC, plus monitoring & security.

## 2. Business Use Case
Customers browse catalog, view sizes/colors, add to cart. Admins manage inventory via DB. Chosen because it exercises product CRUD, images (S3), sessions, and is easy to grade visually.

## 3. Architecture Summary
- **VPC 10.0.0.0/16** with 2 AZs (ap-south-1a/b), public subnets for ALB/NAT, private for EC2/RDS. NAT GW for outbound (patches, ECR pull).
- **Compute:** 1 master + 2 workers (t3.micro, Amazon Linux 2), provisioned by Ansible (docker, kubelet, kubeadm, sysctl, firewalld).
- **Data:** RDS MySQL 8.0 db.t3.micro (20GB gp2, encrypted, backup_retention 0 for free tier — 7 days in production), in private subnets. S3 `myshoe-assets-470999030662` for product images (public-read via bucket policy).
- **Ingress:** ALB (HTTP:80 → target group:8000 → NodePort 30080 on workers). HTTPS deferred — ACM cert for sytes.net requires manual CNAME validation; plan: create cert in console, add CNAME at sytes.net, attach to listener 443.
- **Orchestration:** Kubernetes Deployment (3 replicas, rolling update), Service NodePort, HPA (CPU 70%, 2–6 pods), ConfigMap + Secret, PVC 5Gi gp2.
- **IaC:** Terraform — VPC, subnets, IGW, NAT, routes, SGs, EC2/EIPs, RDS, ALB/TG, S3 (assets + tf-state + DDB locks), ECR, IAM role/instance profile.
- **Automation:** Ansible dynamic inventory `aws_ec2` (tag:Project=myshoe), playbook `playbook.yml`.
- **CI/CD:** GitHub Actions — `ci.yml` (lint/build on PR), `cd.yml` (build → ECR → kubectl rollout). Secrets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, KUBECONFIG.
- **Monitoring:** Prometheus (scrape myshoe-service) + Grafana (NodePort 3000) in namespace `monitoring`; CloudWatch alarms on ALB 5xx + EC2 CPU (TODO: SNS email via `owner_email` var).
- **Security:** Least-privilege SGs (22 SSH open — restrict to your IP in prod, 6443 API, 30080 app), EBS encrypted, RDS encrypted, IAM role with only ECR/CloudWatch/SSM, Docker non-root user, secrets via K8s Secret + tfvars gitignored.

## 4. Phases & Weightage Coverage
| Area | Artefact |
|------|----------|
| Linux 15% | EC2 user-data + Ansible sysctl/firewalld/swap/hostname |
| Ansible 10% | `ansible/playbook.yml` + dynamic inventory |
| AWS 20% | Full Terraform + S3 + ECR + RDS + ALB |
| CI/CD 15% | `.github/workflows/{ci,cd}.yml` |
| Docker 10% | `docker/Dockerfile` + compose + ECR |
| K8s 15% | `kubernetes/*.yaml` + HPA + Ingress |
| Terraform 10% | `terraform/*.tf` modular + outputs + tfvars |
| Monitoring/Security 5% | `monitoring/*.yaml` + SG hardening + secrets |

## 5. Cost Control (free-tier)
t3.micro EC2, db.t3.micro RDS, 1 NAT GW (only hourly cost), 20GB gp2. Tear down with `terraform destroy` when graded.

## 6. Risks
- sytes.net CNAME propagation delay → test via ALB DNS first.
- t3.micro limited RAM for K8s — keep replicas 2–3, or upgrade to t3.small if OOMKilled.
