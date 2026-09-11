# ─── Variables ───────────────────────────────────────────────────────
variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
  default     = "myshoe"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones (ALB + RDS require 2 AZs)"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "instance_type" {
  description = "EC2 instance type (free-tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS instance class (free-tier eligible)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "myshoe"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "app_image_tag" {
  description = "Docker image tag for the app"
  type        = string
  default     = "latest"
}

variable "domain_name" {
  description = "Custom domain (optional, set to empty to skip Route 53)"
  type        = string
  default     = "myshoe.sytes.net"
}

variable "app_port" {
  description = "Application container port"
  type        = number
  default     = 8000
}

variable "owner_email" {
  description = "Email for alerts / notifications"
  type        = string
  default     = "anuvindd@gmail.com"
}
