resource "aws_ecs_task_definition" "svc_hc_postgres" {
  family                   = "svc_hc_postgres"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = "${module.ecs-cluster.ecs_instance_role_arn}"
  task_role_arn            = "${module.ecs-cluster.ecs_instance_role_arn}"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "svc_hc_postgres",
      "image": "hashicorpdemoapp/product-api-db:v0.0.11",
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "app-logs",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "svc_hc_postgres"
        }
      },
      "environment": [
        {
          "name": "POSTGRES_DB",
          "value": "products"
        },
        {
          "name": "POSTGRES_USER",
          "value": "postgres"
        },
        {
          "name": "POSTGRES_PASSWORD",
          "value": "password"
        }
      ],
      "portMappings": [
        {
          "containerPort": 9090,
          "hostPort": 9090,
          "protocol": "tcp"
        }
      ],
      "memory": 512,
      "cpu": 256
    },
    {
      "image": "ppresto/consul-ecs:1.9.3-1.16.0-5",
      "name": "svc_hc_postgres-init",
      "essential": false,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "app-logs",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "svc_hc_postgres-init"
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
              "value": "postgres"
          },
          {
              "name": "SERVICE_PORT",
              "value": "5432"
          },
          {
              "name": "CONSUL_SERVICE",
              "value": "true"
          },
          {
              "name": "CONSUL_SERVICE_KV_PATH",
              "value": "service/postgres/service.json"
          }
      ]
    }
  ]
  DEFINITION
}

resource "aws_ecs_service" "svc_hc_postgres" {
  name            = "svc_hc_postgres"
  cluster         = "${module.ecs-cluster.cluster_id}"
  task_definition = "${aws_ecs_task_definition.svc_hc_postgres.arn}"
  launch_type     = "EC2"
  desired_count   = 1
  # ECS doesn't deal with desired_count=1 for HA.  Setting health% to 0 for clean deployments
  deployment_minimum_healthy_percent = 0

  network_configuration {
    subnets         = data.terraform_remote_state.vpc.outputs.public_subnets
    assign_public_ip = false
    #security_groups  = [aws_security_group.consul_svc.id, aws_security_group.consul_ecs_lb.id]
    security_groups  = [data.terraform_remote_state.consul.outputs.consul_sg, aws_security_group.postgres.id]
  }
}

resource "consul_keys" "postgres" {
  datacenter = var.aws_region
  token      = data.terraform_remote_state.consul.outputs.master_token

  # Set the CNAME of our load balancer as a key
  key {
    path  = "service/postgres/service.json"
    value    = <<VALUE
    {
    "service": {
      "name": "postgres",
      "id": "postgres",
      "token": "",
      "address": "CONTAINER_IP",
      "port": 5432,
      "tags": [
        "ecs",
        "postgres",
        "dev"
      ],
      "meta": {
        {{ range tree "service/postgres/metadata" }}
        "{{- .Key -}}":"{{- .Value -}}",
        {{ end }}
        "meta":"auto-generated-v1"
      },
      "check": {
        "id": "postgres",
        "name": "Postgres TCP on port 5432",
        "tcp": "CONTAINER_IP:5432",
        "interval": "5s",
        "timeout": "1s",
        "DeregisterCriticalServiceAfter": "1m"
      }
    }
  }
  VALUE
  }
}