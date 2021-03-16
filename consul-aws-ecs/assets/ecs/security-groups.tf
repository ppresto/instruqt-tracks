#Add Rule to allow Ext Requests to hit our frontend service
resource "aws_security_group_rule" "frontend_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = module.ecs-cluster.sg_ecs_id
  description              = "Allow all TCP traffic"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "postgres" {
  name        = "postgres-5432"
  description = "ECS postgres service"
  vpc_id      = module.ecs-cluster.vpc_id
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    ecs_cluster = var.cluster_name
    service = "postgres"
  }
}

resource "aws_security_group_rule" "postgres" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.postgres.id
  source_security_group_id = module.ecs-cluster.sg_ecs_id
}

resource "aws_security_group" "consul_ecs_lb" {
  name        = "consul_ecs_lb"
  description = "Allow lb traffic"
  vpc_id      = module.ecs-cluster.vpc_id

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

resource "aws_security_group" "consul_svc" {
  name        = "consul-svc"
  description = "Allow gossip traffic"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    # 8300 Server RPC Traffic on TCP only
    # 8301 LAN Serf used by agents for Gossip on TCP/UDP
    # 8302 WAN Serf on TCP/UDP
    from_port   = 8300
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }
  ingress {
    from_port   = 8301
    to_port     = 8302
    protocol    = "udp"
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }
  ingress {
    # 8500 HTTP
    # 8501 HTTPS
    # 8502 gRPC API Port for Envoy
    from_port   = 8500
    to_port     = 8502
    protocol    = "tcp"
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }

  egress {
    from_port   = 8300
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }

  egress {
    from_port   = 8301
    to_port     = 8302
    protocol    = "udp"
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }
  egress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }
  egress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "udp"
    cidr_blocks = data.terraform_remote_state.vpc.outputs.public_subnets_cidr_blocks
  }

}

