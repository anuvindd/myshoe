# ─── Compute (EC2 for self-managed Kubernetes + bastion optional) ─────
# Master + 2 workers in the private subnet, with public IPs via Elastic IP
# for SSH access. The ALB sits in the public subnet and routes to workers
# through the target group.

resource "aws_security_group" "k8s_nodes" {
  name        = "${var.project_name}-k8s-nodes-sg"
  description = "Security group for K8s master and worker nodes"
  vpc_id      = aws_vpc.main.id

  # SSH from anywhere (restrict to your IP in production via var.ssh_cidr)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K8s API server (master only)
  ingress {
    description = "K8s API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K8s node-to-node communication
  ingress {
    description = "K8s node ports"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # Pod-to-pod and service traffic within cluster VPC
  ingress {
    description = "Cluster internal traffic"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # ALB health checks
  ingress {
    description = "ALB health check"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-k8s-nodes-sg"
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ─── EC2 Master Node ───────────────────────────────────────────────────
# Placed in PUBLIC subnet so SSH via EIP/IGW works (private subnets have only NAT)

resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.k8s_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  key_name = var.ssh_key_name

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Hostname
              hostnamectl set-hostname myshoe-master

              # Disable swap (required by kubelet)
              swapoff -a
              sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

              # Install Docker
              dnf install -y docker
              systemctl enable docker
              systemctl start docker

              # Add ec2-user to docker group
              usermod -aG docker ec2-user

              # Install kubeadm, kubelet, kubectl (Amazon Linux 2023)
              dnf install -y curl
              cat <<'KUBE_REPO' > /etc/yum.repos.d/kubernetes.repo
              [kubernetes]
              name=Kubernetes
              baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
              enabled=1
              gpgcheck=1
              repo_gpgcheck=0
              gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
              exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
              KUBE_REPO

              dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
              systemctl enable kubelet
              systemctl start kubelet

              # Pull control-plane images
              kubeadm config pull

              # Mark node as master-ready (kubeadm init runs after boot via cloud-init
              # or manual step — see README for init command)
              echo "Master node ready. Run kubeadm init on this node after boot."
              EOF

  tags = {
    Name        = "${var.project_name}-master"
    Role        = "k8s-master"
    Environment = var.environment
  }
}

# ─── EC2 Worker Nodes (count = 2) ─────────────────────────────────────
# Spread across both public AZs for HA and ALB health checks

resource "aws_instance" "k8s_worker" {
  count                  = 2
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = element([aws_subnet.public.id, aws_subnet.public_b.id], count.index)
  vpc_security_group_ids = [aws_security_group.k8s_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  key_name = var.ssh_key_name

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e

              hostnamectl set-hostname "myshoe-worker-${count.index + 1}"

              swapoff -a
              sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

              dnf install -y docker
              systemctl enable docker
              systemctl start docker

              usermod -aG docker ec2-user

              dnf install -y curl
              cat <<'KUBE_REPO' > /etc/yum.repos.d/kubernetes.repo
              [kubernetes]
              name=Kubernetes
              baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
              enabled=1
              gpgcheck=1
              repo_gpgcheck=0
              gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
              exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
              KUBE_REPO

              dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
              systemctl enable kubelet
              systemctl start kubelet

              kubeadm config pull

              echo "Worker node ${count.index + 1} ready. Run kubeadm join using the token from master."
              EOF

  tags = {
    Name        = "${var.project_name}-worker-${count.index + 1}"
    Role        = "k8s-worker"
    Environment = var.environment
  }
}

# ─── Elastic IPs for SSH access ────────────────────────────────────────

resource "aws_eip" "master" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-master-eip"
  }
}

resource "aws_eip_association" "master" {
  instance_id   = aws_instance.k8s_master.id
  allocation_id = aws_eip.master.id
}

resource "aws_eip" "worker" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-worker-${count.index + 1}-eip"
  }
}

resource "aws_eip_association" "worker" {
  count         = 2
  instance_id   = aws_instance.k8s_worker[count.index].id
  allocation_id = aws_eip.worker[count.index].id
}

# ─── Data sources ──────────────────────────────────────────────────────

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
