output "aws_region" {
  value = var.aws_region
}
output "vpc_id" {
  value = module.vpc.vpc_id
}
output "private_subnets" {
  value = module.vpc.private_subnets
}
output "public_subnets" {
  value = module.vpc.public_subnets
}
output "public_subnets_cidr_blocks" {
  value = module.vpc.public_subnets_cidr_blocks
}
output "private_subnets_cidr_blocks" {
  value = module.vpc.private_subnets_cidr_blocks
}