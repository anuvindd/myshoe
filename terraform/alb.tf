# ─── ALB ──────────────────────────────────────────────────────────────
# NOTE on myshoe.sytes.net: sytes.net is an external dynamic-DNS provider,
# so DNS is managed there — NOT in Route 53. After `terraform apply`,
# point your domain at the ALB with a CNAME (see outputs + README).
# No Route 53 hosted zone is created.

resource "aws_lb" "app" {
  name               = "${var.project_name}-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-app-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-app-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-app-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "${var.project_name}-http-listener"
  }
}

# ─── ACM Certificate (disabled for free-tier / sytes.net) ───────────
# ACM cert for sytes.net subdomains cannot be auto-validated without
# Route 53, and the ALB fails if the cert is still PENDING_VALIDATION.
# Do HTTPS later: create the cert manually in the console and add the
# CNAME at sytes.net, then uncomment the listener below.
#
# resource "aws_acm_certificate" "app" {
#   domain_name       = var.domain_name
#   validation_method = "DNS"
#   tags = { Name = "${var.project_name}-cert" }
#   lifecycle { create_before_destroy = true }
# }
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.app.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = aws_acm_certificate.app.arn
#   default_action { type = "forward" target_group_arn = aws_lb_target_group.app.arn }
#   tags = { Name = "${var.project_name}-https-listener" }
# }
