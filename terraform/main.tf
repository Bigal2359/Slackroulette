variable "name" {
  description = "the name of your stack, e.g. \"fl-bcg\""
  default = "slackroulette"
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod\""
  default     = "prod"
}

variable "job" {
  default    = "1198561"
}

variable "region" {
  description = "the AWS region in which resources are created, you must set the availability_zones variable as well if you define this value to something other than the default"
  default     = "us-east-1"
}

variable "cidr" {
  description = "The CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "a list of CIDRs for private subnets in your VPC, must be set if the cidr variable is defined, needs to have as many elements as there are availability zones"
  default     = ["10.0.0.0/20", "10.0.32.0/20", "10.0.64.0/20"]
}

variable "public_subnets" {
  description = "a list of CIDRs for public subnets in your VPC, must be set if the cidr variable is defined, needs to have as many elements as there are availability zones"
  default     = ["10.0.16.0/20", "10.0.48.0/20", "10.0.80.0/20"]
}

variable "availability_zones" {
  description = "a comma-separated list of availability zones, defaults to all AZ of the region, if set to something other than the defaults, both private_subnets and public_subnets have to be defined as well"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "service_desired_count" {
  description = "Number of tasks running in parallel"
  default     = 1
}

variable "container_port" {
  description = "The port where the Docker is exposed"
  default     = 3000
}

variable "container_cpu" {
  description = "The number of cpu units used by the task"
  default     = 256
}

variable "container_memory" {
  description = "The amount (in MiB) of memory used by the task"
  default     = 512
}

variable "tsl_certificate_arn" {
  description = "The ARN of the certificate that the ALB uses for https"
  default = "arn:aws:acm:us-east-1:169807124502:certificate/31081086-5f11-46d2-a9d6-f7dff6dcdf00"
}

variable "frontend_name" {
  description = "description"
  default = "slackroulette"
}

variable "frontend_image" {
  description = "description"
  default = "169807124502.dkr.ecr.us-east-1.amazonaws.com/fcb/slackroulette"
}

terraform {
  required_providers {
    aws = "~> 2.44"
  }
  required_version = "~>0.12.0"
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source             = "./vpc"
  name               = var.name
  cidr               = var.cidr
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  availability_zones = var.availability_zones
  environment        = var.environment
  job                = var.job
}

module "security_groups" {
  source         = "./security-groups"
  name           = var.name
  vpc_id         = module.vpc.id
  environment    = var.environment
  container_port = var.container_port
  job            = var.job
}

module "alb" {
  source              = "./alb"
  name                = var.name
  vpc_id              = module.vpc.id
  subnets             = module.vpc.public_subnets
  environment         = var.environment
  alb_security_groups = [module.security_groups.alb]
  alb_tls_cert_arn    = var.tsl_certificate_arn
  health_check_path   = "/healthcheck"
  job                 = var.job
  frontend_name       = var.frontend_name
}

#module "ecr" {
#  source      = "./ecr"
#  name        = var.name
#  environment = var.environment
#}

module "ecs" {
  source                      = "./ecs"
  name                        = var.name
  environment                 = var.environment
  region                      = var.region
  subnets                     = module.vpc.private_subnets
  aws_alb_target_group_frontend_arn    = module.alb.aws_alb_target_group_frontend_arn
  ecs_service_security_groups = [module.security_groups.ecs_tasks]
  container_port              = var.container_port
  container_cpu               = var.container_cpu
  container_memory            = var.container_memory
  #container_image             = module.ecr.aws_ecr_repository_url
  service_desired_count       = var.service_desired_count
  job                         = var.job
  frontend_name               = var.frontend_name
  frontend_image              = var.frontend_image
}
