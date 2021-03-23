#
#  Service ALB
#
resource "aws_alb" "lb_3" {
  name               = "alb-hc-pubapi" # Naming our load balancer
  load_balancer_type = "application"
  subnets = data.terraform_remote_state.vpc.outputs.public_subnets
  # Referencing the security group
  security_groups = ["${module.ecs-cluster.sg_ecs_id}"]
}
resource "aws_lb_target_group" "lb_tg_3" {
  name        = "alb-tg-hc-pubapi"
  port        = 8080
  protocol    = "HTTP"
  #target_type = "ip"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  health_check {
    matcher = "200,301,302"
    path = "/"
    #healthy_threshold   = "3"
    #interval            = "10"
    #protocol            = "HTTP"
    #unhealthy_threshold = "3"
  }
}
resource "aws_lb_listener" "listener_3" {
  load_balancer_arn = "${aws_alb.lb_3.arn}" # Referencing our load balancer
  port              = "8080"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.lb_tg_3.arn}" # Referencing our tagrte group
  }
}

resource "aws_ecs_task_definition" "svc_hc_pubapi" {
  family                   = "svc_hc_pubapi"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = "${module.ecs-cluster.ecs_instance_role_arn}"
  task_role_arn            = "${module.ecs-cluster.ecs_instance_role_arn}"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "svc_hc_pubapi",
      "image": "hashicorpdemoapp/public-api:v0.0.1",
      "dnsServers": ["172.17.0.1","10.0.0.2"],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "app-logs",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "svc_hc_pubapi"
        }
      },
      "environment": [
        {
            "name": "BIND_ADDRESS",
            "value": ":8080"
        },
        {
            "name": "PRODUCT_API_URI",
            "value": "http://product-api.service.consul:9090"
        }
      ],
      "portMappings": [
        {
          "containerPort": 8080
        }
      ],
      "memory": 512,
      "cpu": 256
    },
    {
      "image": "ppresto/consul-ecs:1.9.3-1.16.0-5",
      "name": "svc_hc_pubapi-init",
      "dnsServers": ["172.17.0.1","10.0.0.2"],
      "essential": false,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "app-logs",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "svc_hc_pubapi-init"
        }
      },
      "portMappings": [
          {
              "protocol": "tcp",
              "containerPort": 21000
          }
      ],
      "environment": [
          {
              "name": "SERVICE_NAME",
              "value": "pub-api"
          },
          {
              "name": "CONSUL_SERVICE",
              "value": "true"
          },
          {
              "name": "CONSUL_SERVICE_KV_PATH",
              "value": "service/pub-api/service.json"
          }
      ]
    }
  ]
  DEFINITION
}

resource "aws_ecs_service" "svc_hc_pubapi" {
  name            = "svc_hc_pubapi"
  cluster         = "${module.ecs-cluster.cluster_id}"
  task_definition = "${aws_ecs_task_definition.svc_hc_pubapi.arn}"
  launch_type     = "EC2"
  desired_count   = 1
  deployment_minimum_healthy_percent = 0

  load_balancer {
    target_group_arn = "${aws_lb_target_group.lb_tg_3.arn}" # Referencing our target group
    container_name   = "${aws_ecs_task_definition.svc_hc_pubapi.family}"
    container_port   = 8080 # Specifying the container port
  }

  #network_configuration {
  #  subnets         = data.terraform_remote_state.vpc.outputs.public_subnets
  #  assign_public_ip = false
  #  security_groups  = [aws_security_group.consul_svc.id, aws_security_group.consul_ecs_lb.id]
  #}
  depends_on              = ["aws_lb_listener.listener_3"]
}

resource "consul_keys" "pub-api" {
  datacenter = var.aws_region
  token      = data.terraform_remote_state.consul.outputs.master_token

  # Set the CNAME of our load balancer as a key
  key {
    path  = "service/pub-api/service.json"
    value    = <<VALUE
    { "service":
      { "name": "pub-api",
        "id": "pub-api-SERVICE_PORT",
        "token": "",
        "address": "EC2_HOST_IP",
        "port": SERVICE_PORT,
        "tags": [
          "ecs",
          "pub-api",
          "dev"
        ],
        "meta": {
          {{ range tree "service/pub-api/metadata" }}
          "{{- .Key -}}":"{{- .Value -}}",
          {{ end }}
          "meta":"auto-generated-v1"
        },
        "checks": [
          {
              "id": "pub-api-SERVICE_PORT-tcp-8080",
              "name": "Public API - TCP 8080",
              "tcp": "CONTAINER_IP:8080",
              "interval": "10s",
              "timeout": "1s"
          },
          {
              "id": "pub-api-SERVICE_PORT-http-8080",
              "name": "Public API - HTTP 8080",
              "http": "http://CONTAINER_IP:8080",
              "tls_skip_verify": true,
              "interval": "5s",
              "timeout": "2s"
          },
          {
              "id": "pub-api-tcp-ec2-SERVICE_PORT",
              "name": "EC2 TCP Port Mapping - SERVICE_PORT",
              "tcp": "EC2_HOST_IP:SERVICE_PORT",
              "interval": "10s",
              "timeout": "2s",
              "DeregisterCriticalServiceAfter": "1m"
          }
        ]
      }
    }
    VALUE
  }
}

output "alb_hc_pubapi" {
  value = aws_alb.lb_3.dns_name
}
