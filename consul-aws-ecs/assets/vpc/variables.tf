variable "cluster_name" {
  description = "The name to use to create the cluster and the resources. Only alphanumeric characters and dash allowed (e.g. 'my-cluster')"
}
variable "aws_region" {
  default     = "us-east-1"
  description = "The AWS region where to launch the cluster and releated resources"
}

variable "vpc_id" {
  default     = "invalid-vpc"
  type        = string
  description = "A VPC where the EC2 instances will be launched in. Either pass this variable or \"create_vpc=true\""
}
variable "subnet_ids" {
  description = "A list of subnet IDs in which to launch EC2 instances in"
  type        = list(string)
  default = [
    "non-existing-1",
    "non-existing-2"
  ]
}

variable "key_name" {
  description  = "SSH Key Name to use for all instances"
  default      = "ppresto-ptfe-dev-key"
}