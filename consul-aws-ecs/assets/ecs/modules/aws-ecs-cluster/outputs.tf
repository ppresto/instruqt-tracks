output "aws_region" {
  value = var.aws_region
}
output "cluster_id" {
  value = aws_ecs_cluster.ecs_cluster.id
}
output "vpc_id" {
  value = data.aws_vpc.main.id
}
#output "private_subnets" {
#  value = var.subnet_ids
#}
output "public_subnets" {
  value = var.subnet_ids
}
output "sg_ecs_id" {
  value = aws_security_group.sg_for_ec2_instances.id
}
output "ecs_instance_role_arn" {
  value = aws_iam_role.ecs_role.arn
}
