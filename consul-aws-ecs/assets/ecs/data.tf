data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../vpc/terraform.tfstate"
  }
}

data "terraform_remote_state" "consul" {
  backend = "local"

  config = {
    path = "../consul/terraform.tfstate"
  }
}
