resource "aws_security_group" "consul_ssh" {
  name        = "consul-ssh"
  description = "Allow ssh traffic"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_block
  }
}

resource "aws_security_group" "consul_lb" {
  name        = "consul-lb"
  description = "Allow lb traffic"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port       = 8500
    to_port         = 8500
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 8501
    to_port         = 8501
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "consul_lb2" {
  name        = "consul-lb2"
  description = "Allow lb traffic"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    #cidr_blocks = var.consul_ui_cidr_block
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "consul_segments" {
  for_each = var.network_segments

  name        = "consul-segments-${each.key}"
  description = "Allow gossip traffic"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port   = 8300
    to_port     = 8300
    protocol    = "tcp"
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }

  ingress {
    from_port   = each.value
    to_port     = each.value
    protocol    = "tcp"
    #cidr_blocks = ["10.2.0.0/16", "10.3.0.0/16"]
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }

  ingress {
    from_port   = each.value
    to_port     = each.value
    protocol    = "udp"
    #cidr_blocks = ["10.2.0.0/16", "10.3.0.0/16"]
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }

  egress {
    from_port   = 8300
    to_port     = 8300
    protocol    = "tcp"
    #cidr_blocks = ["10.2.0.0/16", "10.3.0.0/16"]
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }

  egress {
    from_port   = each.value
    to_port     = each.value
    protocol    = "tcp"
    #cidr_blocks = ["10.2.0.0/16", "10.3.0.0/16"]
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }

  egress {
    from_port   = each.value
    to_port     = each.value
    protocol    = "udp"
    #cidr_blocks = ["10.2.0.0/16", "10.3.0.0/16"]
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }

}
