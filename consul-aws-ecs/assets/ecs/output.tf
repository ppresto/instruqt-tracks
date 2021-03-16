output "aws_region" {
  value = module.ecs-cluster.aws_region
}
output "cluster_id" {
  value = module.ecs-cluster.cluster_id
}
output "cluster_name" {
  value = var.cluster_name
}
output "vpc_id" {
  value = data.terraform_remote_state.vpc.outputs.vpc_id
}
output "private_subnets" {
  value = data.terraform_remote_state.vpc.outputs.private_subnets
}
output "public_subnets" {
  value = data.terraform_remote_state.vpc.outputs.public_subnets
}
output "sg_ecs_id" {
  value = module.ecs-cluster.sg_ecs_id
}
output "alb_hc_frontend" {
  value = aws_alb.alb_frontend.dns_name
}
