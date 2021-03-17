provider "aws" {
  region  = var.aws_region
  version = "~> 2.5"
}
data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../vpc/terraform.tfstate"
  }
}

# Get AZs for the current AWS region
data "aws_availability_zones" "available" {
  state = "available"
}

module "consul" {
  source = "./modules/is-immutable-aws-consul"
  ami_owner     = var.ami_owner
  instance_type = "t3.large"
  ami_release   = var.ami_release
  consul_cluster_version = var.consul_cluster_version
  bootstrap              = var.bootstrap

  enable_connect = true

  key_name    = var.key_name
  name_prefix = var.name_prefix
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  subnets     = data.terraform_remote_state.vpc.outputs.public_subnets

  region      = var.aws_region
  availability_zones = [
    data.aws_availability_zones.available.names[0],
    data.aws_availability_zones.available.names[1],
    data.aws_availability_zones.available.names[2]
  ]

  public_ip = false

  consul_nodes     = "3"
  redundancy_zones = false
  performance_mode = false
  enable_snapshots = true
  # This is the owner tag on EC2 instance
  owner = var.ami_owner
  ttl   = "-1"

  additional_security_group_ids = [aws_security_group.consul_ssh.id, aws_security_group.consul_lb.id]

  #consul_tls_config = module.consul_tls.consul_tls_config

}

#module "consul_tls" {
#  source            = "./modules/tls-self-signed"
#  consul_datacenter = var.aws_region
#  environment_name  = module.consul.env
#  dns_names         = [aws_lb.consul.dns_name,"server.${var.aws_region}.consul", "localhost"]
#}
