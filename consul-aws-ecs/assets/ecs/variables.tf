variable "aws_region" {
  default     = "us-east-1"
  description = "The AWS region where to launch the cluster and releated resources"
}

variable "ssh_key_name" {
  description = "SSH key to use to enter and manage the EC2 instances within the cluster. Optional"
  default     = "ppresto-ptfe-dev-key"
}

#variable "create_vpc" {
#  default     = true
#  description = "Create a new VPC for ECS"
#}

variable "cluster_name" {
  default     = "ecs-presto"
  description = "ECS Cluster Name"
}

variable "consul_ecs_agent_image_name" {
  default     = "joatmon08/consul-ecs:v1.9.1-v1.16.0"
  description = " Consul-ECS registeration init/sidecar container image"
}

variable "min_spot_instances" {
  default     = "1"
  description = "The minimum EC2 spot instances to have available within the cluster when the cluster receives less traffic"
}
variable "max_spot_instances" {
  default     = "5"
  description = "The maximum EC2 spot instances that can be launched during period of high traffic"
}