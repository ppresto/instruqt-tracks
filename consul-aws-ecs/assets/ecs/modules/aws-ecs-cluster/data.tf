data "aws_region" "current" {
  name = var.aws_region
}
data "aws_vpc" "main" {
  id = var.vpc_id
}
# Get AZs for the current AWS region
data "aws_availability_zones" "available" {
  state = "available"
}
