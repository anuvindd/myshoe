# Deployment Guide — MyShoe

## 0) Prereqs on your machine
- AWS CLI configured (newuser, ap-south-1) — `aws sts get-caller-identity` works
- `C:\Users\anuvi\bin\terraform.exe` on PATH (`terraform --version`)
- `myshoe.pem` at `C:\Users\anuvi\Downloads\myshoe.pem` (chmod 400)
- Docker Desktop for `docker build` + `aws ecr get-login-password`

## 1) Infra (done — outputs below)
```bash
cd C:/Users/anuvi/Documents/myshoe/terraform
terraform output
# alb_dns_name = "myshoe-app-alb-1194032437.ap-south-1.elb.amazonaws.com"
```
At sytes.net provider: `myshoe` CNAME → that ALB DNS. Test via `curl http://<ALB-DNS>/health`.

## 2) Patch K8s manifests with live outputs
```bash
cd C:/Users/anuvi/Documents/myshoe
bash scripts/update-config.sh
# or manually: set DB_HOST in kubernetes/configmap-secret.yaml to the RDS endpoint
```

## 3) Provision nodes with Ansible
```bash
pip install ansible boto3
ansible-galaxy collection install amazon.aws
export AWS_REGION=ap-south-1
ansible-playbook -i ansible/inventories/aws_ec2.yml ansible/playbook.yml -u ec2-user --private-key C:/Users/anuvi/Downloads/myshoe.pem
```

## 4) Init Kubernetes (on master via SSH)
```bash
ssh -i ~/Downloads/myshoe.pem ec2-user@15.207.57.86
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=10.0.2.151
mkdir -p ~/.kube; sudo cp /etc/kubernetes/admin.conf ~/.kube/config; sudo chown $(id -u):$(id -g) ~/.kube/config
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
# copy the `kubeadm join ...` line, then on each worker:
ssh -i ~/Downloads/myshoe.pem ec2-user@15.252.54.155 "sudo <join-cmd>"
ssh -i ~/Downloads/myshoe.pem ec2-user@13.207.231.99 "sudo <join-cmd>"
kubectl get nodes
```

## 5) Build & push app image
```bash
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 470999030662.dkr.ecr.ap-south-1.amazonaws.com
docker build -t 470999030662.dkr.ecr.ap-south-1.amazonaws.com/myshoe-app:latest -f docker/Dockerfile docker/app
docker push 470999030662.dkr.ecr.ap-south-1.amazonaws.com/myshoe-app:latest
```

## 6) Deploy to K8s
```bash
scp -i ~/Downloads/myshoe.pem -r kubernetes ec2-user@15.207.57.86:~/kubernetes
ssh -i ~/Downloads/myshoe.pem ec2-user@15.207.57.86
kubectl apply -f kubernetes/configmap-secret.yaml
kubectl create secret generic myshoe-secret --from-literal=DB_PASSWORD=$(grep db_password ~/terraform/terraform.tfvars | cut -d'"' -f2) --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f kubernetes/app.yaml
kubectl apply -f kubernetes/ingress-pvc.yaml
kubectl apply -f monitoring/prometheus-grafana.yaml
kubectl get pods -A
kubectl get svc myshoe-service
```

## 7) Wire ALB to workers
In EC2 → Target Groups → myshoe-app-tg → Register targets: add workers `10.0.2.30:30080` and `10.0.2.140:30080`. Health check `/health` should go green within 30s.

## 8) Verify
```bash
curl http://myshoe-app-alb-1194032437.ap-south-1.elb.amazonaws.com/health
curl http://myshoe.sytes.net/health   # after CNAME propagates
```

## 9) CI/CD
Push to GitHub → Actions runs `ci.yml` (PR) and `cd.yml` (main → ECR → rollout). Set repo secrets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, KUBECONFIG (base64 of master ~/.kube/config).

## 10) Tear down (avoid charges)
```bash
terraform destroy -auto-approve
```

## Troubleshooting
- `FreeTierRestrictionError` — already fixed (backup_retention 0).
- `UnsupportedCertificate` — HTTPS listener is commented out; use HTTP until you manually create/validate ACM cert at sytes.net.
- `ImagPullBackOff` — `aws ecr get-login-password` + re-push; check instance profile has ECR read.
