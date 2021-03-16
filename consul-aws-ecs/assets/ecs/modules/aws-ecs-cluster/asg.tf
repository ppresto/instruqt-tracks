module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "3.8"

  name = "${var.cluster_name}_asg"

  # Launch configuration
  lc_name = "${var.cluster_name}_launchconfig"

  image_id             = data.aws_ami.ecs.id
  instance_type        = var.instance_type_spot
  security_groups      = flatten([aws_security_group.sg_for_ec2_instances.id, var.additional_security_group_ids])
  iam_instance_profile = aws_iam_instance_profile.ec2_iam_instance_profile.arn
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true
  user_data = var.ecs_ec2_user_data != "" ? var.ecs_ec2_user_data : templatefile("${path.module}/templates/ecs-ec2-init.tpl", {cluster_name = var.cluster_name})
  # Auto scaling group
  asg_name                    = "${var.cluster_name}_asg"
  vpc_zone_identifier         = var.subnet_ids
  health_check_type           = "EC2"
  min_size                    = var.min_spot_instances
  max_size                    = var.max_spot_instances
  desired_capacity            = var.min_spot_instances
  wait_for_capacity_timeout   = 0

  tags = [
    {
      key                 = "Name"
      value               = var.cluster_name,
      propagate_at_launch = true
    }
  ]
}