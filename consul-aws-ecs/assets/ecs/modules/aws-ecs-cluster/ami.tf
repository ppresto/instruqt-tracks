# Lookup the current ECS AMI.
# In a production environment you probably want to
# hardcode the AMI ID, to prevent upgrading to a
# new and potentially broken release.
data "aws_ami" "ecs" {
  most_recent = true

  filter {
    name = "name"
    values = [
    "amzn2-ami-ecs-*"] # ECS optimized image
  }

  filter {
    name = "virtualization-type"
    values = [
    "hvm"]
  }
  filter {
      name   = "architecture"
      values = ["x86_64"]
  }


  owners = [
    "amazon"
  ]
}
