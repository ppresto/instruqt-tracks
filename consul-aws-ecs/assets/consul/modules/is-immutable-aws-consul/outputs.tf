output "env" {
  value = random_id.environment_name.hex
}

output "aws_autoscaling_group_id" {
  value = aws_autoscaling_group.consul.id
}

output "http_target_group" {
  value = aws_lb_target_group.consul_http.id
}

output "https_target_group" {
  value = aws_lb_target_group.consul_https.id
}

output "master_token" {
  value = random_uuid.consul_master_token.result
}

output "agent_server_token" {
  value = random_uuid.consul_agent_server_token.result
}

output "snapshot_token" {
  value = random_uuid.consul_snapshot_token.result
}

output "gossip_key" {
  value = random_id.consul_gossip_encryption_key.b64_std
}

output "consul_sg" {
  value = aws_security_group.consul.id
}

output "dns_name" {
  value = aws_lb.consul.dns_name
}
