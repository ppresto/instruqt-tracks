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
  default     = "0.0.1"
}

variable "ami_owner" {
  description = "AMI owner to target in the filter"
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

variable "name_prefix" {
  default     = "hashicorp"
  description = "prefix used in resource names"
}

variable "key_name" {
  description = "SSH Key Name to use for all instances"
  default     = "ppresto-ptfe-dev-key"
}

variable "consul_ui_cidr_block" {
  description = "Limit Ext UI Access to the following CIDR block"
  #default      = ["0.0.0.0/0"]
  default = ["0.0.0.0/0"]
}
variable "ssh_cidr_block" {
  description = "Limit Ext UI Access to the following CIDR block"
  #default      = ["0.0.0.0/0"]
  default = ["0.0.0.0/0"]
}

variable "enable_gossip_encryption" {
  type        = bool
  description = "Encrypt all gossip traffic with secret token"
  default     = false
}
variable "enable_acl_system" {
  type        = bool
  description = "Enable ACL system"
  default     = false
}
variable "acl_system_default_policy" {
  description = "Enable ACL system"
  default     = "allow"
}
variable "enable_tls" {
  type        = bool
  description = "Enable ACL system"
  default     = false
}