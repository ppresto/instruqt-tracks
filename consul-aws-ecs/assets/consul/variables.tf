variable "aws_region" {
  default     = "us-east-1"
  description = "The AWS region where to launch the cluster and releated resources"
}

variable "consul_nodes" {
  description = "number of Consul instances"
}

variable "consul_cluster_version" {
  description = "Custom version tag for upgrade migrations"
}

variable "ami_release" {
  description = "Custom version tag for upgrade migrations"
  default = "0.0.1"
}

variable "bootstrap" {
  type        = bool
  description = "Initial bootstrap configurations"
}

variable "extra_config" {
  description = "HCL Object with additional configuration overrides supplied to the consul servers."
  default     = {}
}

variable "network_segments" {
  description = "Name and port mapping for segment"
  type        = map
  default     = {}
}

variable "key_name" {
  description  = "SSH Key Name to use for all instances"
  default      = "ppresto-ptfe-dev-key"
}

variable "consul_ui_cidr_block" {
  description  = "Limit Ext UI Access to the following CIDR block"
  #default      = ["0.0.0.0/0"]
  default      = ["52.119.127.230/32"]
}
variable "ssh_cidr_block" {
  description  = "Limit Ext UI Access to the following CIDR block"
  #default      = ["0.0.0.0/0"]
  default      = ["52.119.127.230/32"]
}