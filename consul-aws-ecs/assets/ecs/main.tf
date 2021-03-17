module "ecs-cluster" {
  source = "./modules/aws-ecs-cluster"

  cluster_name = var.cluster_name
  aws_region = var.aws_region
  ssh_key_name = var.ssh_key_name
  additional_security_group_ids = [data.terraform_remote_state.consul.outputs.consul_sg]
  ecs_ec2_user_data = templatefile("${path.module}/templates/ecs-ec2-init.sh", {cluster_name = var.cluster_name})

  # EC2 instances will live within this VPC
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  # Launch EC2 instances within these subnets
  subnet_ids = data.terraform_remote_state.vpc.outputs.public_subnets
}

# ECS Cluster Cloudwatch Log Group.  Task definition will reference "app-logs" directly.
resource "aws_cloudwatch_log_group" "log_group" {
  name = "app-logs"
    tags = {
    Environment = "production"
  }
}