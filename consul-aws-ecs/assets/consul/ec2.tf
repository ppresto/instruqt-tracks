data "aws_ami" "ubuntu" {
  owners = ["099720109477"]

  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "ec2-vault-svcs" {
  name        = "ppresto-ec2"
  description = "ppresto vault svc ec2 host"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2-vault-svcs" {
  instance_type               = "t3.small"
  ami                         = data.aws_ami.ubuntu.id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.consul_ssh.id, module.consul.consul_sg, aws_security_group.ec2-vault-svcs.id]
  subnet_id                   = data.terraform_remote_state.vpc.outputs.public_subnets[0]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  user_data                   = templatefile("${path.module}/scripts/install_consul.sh.tpl", local.install_ec2_tpl)
  tags = {
    Name = "Vault"
    Owner = "ppresto"
  }
}

resource "aws_security_group" "vault_lb" {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_lb_target_group" "vault" {
  port        = 8200
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "instance"

  health_check {
    path     = "/v1/sys/health"
    port     = "8200"
    protocol = "HTTP"
  }
}

resource "aws_lb" "vault" {
  name               = "vault-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.vault_lb.id}"]
  subnets            = data.terraform_remote_state.vpc.outputs.public_subnets
}

resource "aws_lb_listener" "vault" {
  load_balancer_arn = "${aws_lb.vault.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.vault.arn}"
  }
}

resource "aws_lb_target_group_attachment" "vault" {
  target_group_arn = aws_lb_target_group.vault.arn
  target_id        = aws_instance.ec2-vault-svcs.id
  port             = 8200
}

locals {
  install_ec2_tpl = {
    CONSUL_VER             = "1.8.0"
    environment_name       = "${module.consul.env}-consul"
    datacenter             = var.aws_region
    gossip_key             = module.consul.random_id.consul_gossip_encryption_key.b64_std
    master_token           = module.consul.random_uuid.consul_master_token.result
  }
}