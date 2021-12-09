# Create Consul Policy for Vault to manage ACL Tokens
data "consul_acl_policy" "management" {
  name = "global-management"
}
 
resource "consul_acl_token" "vault" {
  description = "ACL token for Consul secrets engine in Vault"
  policies    = [data.consul_acl_policy.management.name]
  local       = true
}

data "consul_acl_token_secret_id" "vault" {
  accessor_id = consul_acl_token.vault.id
}

# Configure the Vault Consul secrets engine
resource "vault_consul_secret_backend" "consul" {
 path                      = "consul"
 description               = "Manages the Consul backend"
 address                   = data.terraform_remote_state.consul.outputs.dns_name
 token                     = data.consul_acl_token_secret_id.vault.secret_id
 default_lease_ttl_seconds = 3600
 max_lease_ttl_seconds     = 3600
}

# Create service registration policy and role
resource "consul_acl_policy" "frontend" {
  name        = "frontend_policy"
  datacenters = ["${data.terraform_remote_state.vpc.outputs.aws_region}"]
  rules       = <<-RULE
    service_prefix "frontend" {
        policy = "write"
    }
    RULE
}
resource "vault_consul_secret_backend_role" "frontend" {
  name    = "frontend"
  backend = vault_consul_secret_backend.consul.path
  policies = [
    consul_acl_policy.frontend.name,
  ]
}

resource "consul_acl_policy" "postgres" {
  name        = "postgres_policy"
  datacenters = ["${data.terraform_remote_state.vpc.outputs.aws_region}"]
  rules       = <<-RULE
    service_prefix "postgres" {
        policy = "write"
    }
    RULE
}
resource "vault_consul_secret_backend_role" "postgres" {
  name    = "postgres"
  backend = vault_consul_secret_backend.consul.path
  policies = [
    consul_acl_policy.postgres.name,
  ]
}

resource "consul_acl_policy" "product-api" {
  name        = "product-api_policy"
  datacenters = ["${data.terraform_remote_state.vpc.outputs.aws_region}"]
  rules       = <<-RULE
    service_prefix "product-api" {
        policy = "write"
    }
    RULE
}
resource "vault_consul_secret_backend_role" "product-api" {
  name    = "product-api"
  backend = vault_consul_secret_backend.consul.path
  policies = [
    consul_acl_policy.product-api.name,
  ]
}

resource "consul_acl_policy" "pub-api" {
  name        = "pub-api_policy"
  datacenters = ["${data.terraform_remote_state.vpc.outputs.aws_region}"]
  rules       = <<-RULE
    service_prefix "pub-api" {
        policy = "write"
    }
    RULE
}
resource "vault_consul_secret_backend_role" "pub-api" {
  name    = "pub-api"
  backend = vault_consul_secret_backend.consul.path
  policies = [
    consul_acl_policy.pub-api.name,
  ]
}