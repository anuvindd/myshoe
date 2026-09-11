# ─── Outputs ──────────────────────────────────────────────────────────

output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "k8s_master_public_ip" {
  value = aws_eip.master.public_ip
}

output "k8s_master_private_ip" {
  value = aws_instance.k8s_master.private_ip
}

output "k8s_worker_public_ips" {
  value = [for i, w in aws_instance.k8s_worker : aws_eip.worker[i].public_ip]
}

output "k8s_worker_private_ips" {
  value = [for w in aws_instance.k8s_worker : w.private_ip]
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "alb_dns_zone_id" {
  value = aws_lb.app.zone_id
}

output "rds_endpoint" {
  value     = aws_db_instance.myshoe.endpoint
  sensitive = true
}

output "rds_port" {
  value = aws_db_instance.myshoe.port
}

output "rds_database_name" {
  value = aws_db_instance.myshoe.db_name
}

output "rds_username" {
  value     = aws_db_instance.myshoe.username
  sensitive = true
}

output "s3_assets_bucket" {
  value = aws_s3_bucket.assets.bucket
}

output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ssh_key_name" {
  value = var.ssh_key_name
}
