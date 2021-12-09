#terraform {
#  required_version = ">= 0.13"
#}

provider "aws" {
  region  = var.aws_region
  #version = "~> 3.27.0"
  #version = "~> 2.70.0"
}

provider "consul" {
  address    = data.terraform_remote_state.consul.outputs.dns_name
  datacenter = var.aws_region
  token = data.terraform_remote_state.consul.outputs.master_token
}

provider "vault" {
  address = "http://${data.terraform_remote_state.consul.outputs.vault_url}"
}

terraform {
  required_version = ">= 0.13"
  required_providers {
    # In the rare situation of using two providers that
    # have the same type name -- "http" in this example --
    # use a compound local name to distinguish them.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "= 2.11.0"
    }
    null = {
      source = "hashicorp/null"
      version = "= 3.1.0"
    }
    random = {
      source = "hashicorp/random"
      version = "= 3.1.0"
    }
  }
}