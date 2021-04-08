output "env" {
  value = module.consul.env
}

output "dns_name" {
  value = module.consul.dns_name
}

output "consul_sg" {
  value = module.consul.consul_sg
}

output "ca" {
  value = module.consul_tls.consul_tls_config.ca_cert
}

output "master_token" {
  value     = module.consul.master_token
  sensitive = true
}

output "agent_server_token" {
  value     = module.consul.agent_server_token
  sensitive = true
}

output "snapshot_token" {
  value     = module.consul.snapshot_token
  sensitive = true
}

output "gossip_key" {
  value     = module.consul.gossip_key
  sensitive = true
}

output "ec2_ip" {
  value = "ssh ubuntu@${aws_instance.ec2-vault-svcs.public_ip}"
}

output "vault_url" {
  value = aws_lb.vault.dns_name
}