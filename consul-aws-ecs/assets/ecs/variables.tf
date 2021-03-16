variable "aws_region" {
  default     = "us-east-1"
  description = "The AWS region where to launch the cluster and releated resources"
}

variable "create_vpc" {
  default     = true
  description = "Create a new VPC for ECS"
}

variable "cluster_name" {
  default     = "ecs-presto"
  description = "ECS Cluster Name"
}