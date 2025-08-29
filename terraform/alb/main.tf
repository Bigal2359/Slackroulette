variable "name" {
  description = "the name of your stack, e.g. \"fl-bcg\""
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod\""
}

variable "subnets" {
  description = "Comma separated list of subnet IDs"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "alb_security_groups" {
  description = "Environment tag, e.g prod"
}

variable "alb_tls_cert_arn" {
  description = "The ARN of the certificate that the ALB uses for https"
}

variable "health_check_path" {
  description = "Path to check if the service is healthy, e.g. /status"
}

variable "job" {
  description = "Job number used for project"
}

variable "frontend_name" {
  description = "Frontend name"
}

resource "aws_lb" "main" {
  name               = "${var.name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.alb_security_groups
  subnets            = var.subnets.*.id

  enable_deletion_protection = false

  tags = {
    Name        = "${var.name}-alb-${var.environment}"
    Environment = var.environment
    "Job Number" = var.job
  }
}

resource "aws_alb_target_group" "frontend" {
  name        = "${var.frontend_name}-tg-${var.environment}"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/healthcheck"
    unhealthy_threshold = "2"
  }

  tags = {
    Name         = "${var.frontend_name}-tg-${var.environment}"
    Environment  = var.environment
    "Job Number" = var.job
  }
}


# Redirect to https listener
resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Redirect traffic to target group
resource "aws_alb_listener" "https" {
    load_balancer_arn = aws_lb.main.id
    port              = 443
    protocol          = "HTTPS"

    ssl_policy        = "ELBSecurityPolicy-2016-08"
    certificate_arn   = var.alb_tls_cert_arn

    default_action {
        target_group_arn = aws_alb_target_group.frontend.id
        type             = "forward"
    }
}

output "aws_alb_target_group_frontend_arn" {
  value = aws_alb_target_group.frontend.arn
}
