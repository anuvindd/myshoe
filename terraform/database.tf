# ─── RDS MySQL ─────────────────────────────────────────────────────────
# Free-tier eligible: db.t3.micro, 20 GB gp2 storage, multi-AZ disabled
# (single-AZ to stay within free tier; HA can be demonstrated via backup
#  retention + read replica concept in the proposal)

resource "aws_db_subnet_group" "myshoe" {
  name       = "${var.project_name}-db-subnet-group"
  description = "Subnet group for myshoe RDS instance"

  subnet_ids = [
    aws_subnet.private.id,
    aws_subnet.private_b.id,
  ]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "myshoe" {
  identifier     = "${var.project_name}-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password != "" ? var.db_password : random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.myshoe.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot       = true
  deletion_protection       = false
  publicly_accessible       = false
  storage_encrypted         = true
  storage_type              = "gp2"
  backup_retention_period   = 0
  copy_tags_to_snapshot     = true
  delete_automated_backups  = true

  # Free-tier: keep multi-az off; enable it in proposal as "next step"
  multi_az               = false
  monitoring_interval    = 0
  performance_insights_enabled = false

  tags = {
    Name = "${var.project_name}-mysql"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS MySQL - accessible only from K8s nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "MySQL from K8s nodes"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# Random password if none provided via variable
resource "random_password" "db" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
