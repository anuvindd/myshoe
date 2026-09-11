# Network Diagram — MyShoe (ap-south-1)

VPC: 10.0.0.0/16 (vpc-0ce837376db8c25be)

AZ ap-south-1a:
  Public  10.0.1.0/24  subnet-08ddc9a2211e17f51  → route 0.0.0.0/0 → IGW
    - NAT GW nat-057490b1ef18f81c2 (EIP)
    - ALB ENI (a)
  Private 10.0.2.0/24  subnet-07db745089f6cd75c  → route 0.0.0.0/0 → NAT GW
    - master 10.0.2.151 (i-05d6842e14a996e59, EIP 15.207.57.86)
    - worker0 10.0.2.30 (EIP 15.252.54.155)
    - RDS ENI (db-MIEJKA...)

AZ ap-south-1b:
  Public  10.0.3.0/24  (public_b)  → same IGW route
    - ALB ENI (b)
  Private 10.0.4.0/24  (private_b) → same NAT route
    - worker1 10.0.2.140 (note: placed in private 10.0.2.0/24 today — move to 10.0.4.0/24 on next `apply` if desired; both AZ private subnets share the NAT route)
    - RDS standby ENI

Security Groups:
  myshoe-alb-sg:    ingress 80,443 from 0.0.0.0/0; egress all
  myshoe-k8s-nodes-sg: ingress 22 0.0.0.0/0, 6443 0.0.0.0/0, 10250 VPC, 30080/8000 0.0.0.0/0 (ALB health), all TCP VPC for pod traffic; egress all
  myshoe-rds-sg:    ingress 3306 from 10.0.0.0/16; egress all

Flow:
  Client → IGW → ALB (public) → (NodePort 30080) → workers (private via NAT for pulls) → RDS (private, 3306)
  Workers → NAT → Internet (ECR pull, apt, k8s images)
  SSH: Internet → EIP → workers/master (22)

DNS:
  myshoe.sytes.net  CNAME  myshoe-app-alb-1194032437.ap-south-1.elb.amazonaws.com  (set at sytes.net provider)
  No Route 53 zone — sytes.net is external. ACM validation CNAME must be added at sytes.net manually when you create the cert.
