variable "name" {
  description = "the name of your stack, e.g. \"fl-bcg\""
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod\""
}

variable "region" {
  description = "the AWS region in which resources are created, you must set the availability_zones variable as well if you define this value to something other than the default"
}

variable "subnets" {
  description = "List of subnet IDs"
}

variable "ecs_service_security_groups" {
  description = "Comma separated list of security groups"
}

variable "container_port" {
  description = "Port of container"
}

variable "container_cpu" {
  description = "The number of cpu units used by the task"
}

variable "container_memory" {
  description = "The amount (in MiB) of memory used by the task"
}

#variable "container_image" {
#  description = "Docker image to be launched"
#}

variable "aws_alb_target_group_frontend_arn" {
  description = "ARN of the alb target group"
}

variable "service_desired_count" {
  description = "Number of services running in parallel"
}

variable "job" {
  description = "Job number used for project"
}

variable "frontend_name" {
  description = "Name of the frontend container"
}

variable "frontend_image" {
  description = "Image used for the frontend container"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.name}-ecsTaskExecutionRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
    role = aws_iam_role.ecs_task_execution_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "frontend" {
  name = "/ecs/${var.frontend_name}-task-${var.environment}"

  tags = {
    Name        = "${var.frontend_name}-task-${var.environment}"
    Environment = var.environment
    "Job Number" = var.job
  }
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.frontend_name}-task-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = jsonencode([{
      name             = "${var.frontend_name}-container-${var.environment}"
      image            = "${var.frontend_image}:latest"
      essential        = true
      portMappings = [{
        protocol      = "tcp"
        containerPort = 3000
        hostPort      = 3000
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.frontend.name
          awslogs-stream-prefix = "ecs"
          awslogs-region        = var.region
        }
      }
    }])

  tags = {
    Name        = "${var.frontend_name}-task-${var.environment}"
    Environment = var.environment
    "Job Number" = var.job
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}-cluster-${var.environment}"
  tags = {
    Name        = "${var.name}-cluster-${var.environment}"
    Environment = var.environment
    "Job Number" = var.job
  }
}

resource "aws_ecs_service" "frontend" {
  name                               = "${var.frontend_name}-service-${var.environment}"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.frontend.arn
  desired_count                      = var.service_desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"

  network_configuration {
    security_groups  = var.ecs_service_security_groups
    subnets          = var.subnets.*.id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.aws_alb_target_group_frontend_arn
    container_name   = "${var.frontend_name}-container-${var.environment}"
    container_port   = 3000
  }

  # we ignore task_definition changes as the revision changes on deploy
  # of a new version of the application
  lifecycle {
    ignore_changes = [task_definition]
  }
}