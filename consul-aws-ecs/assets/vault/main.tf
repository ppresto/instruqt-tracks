provider "aws" {
  version = "~> 2.0"
  region  = var.aws_region
}

data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../vpc/terraform.tfstate"
  }
}
