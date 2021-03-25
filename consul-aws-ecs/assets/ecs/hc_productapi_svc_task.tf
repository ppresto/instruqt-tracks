resource "aws_ecs_task_definition" "svc_hc_productapi" {
  family                   = "svc_hc_productapi"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = "${module.ecs-cluster.ecs_instance_role_arn}"
  task_role_arn            = "${module.ecs-cluster.ecs_instance_role_arn}"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "svc_hc_productapi",
      "image": "hashicorpdemoapp/product-api:v0.0.11",
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "app-logs",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "svc_hc_productapi"
        }
      },
      "environment": [
        {
          "name": "CONFIG_FILE",
          "value": "/etc/secrets/db-creds"
        }
      ],
      "mountPoints" : [
        {
          "containerPath" : "/etc/secrets/db-creds",
          "sourceVolume" : "productapi",
          "readOnly": true
        }
      ],
      "portMappings": [
        {
          "containerPort": 9090,
          "protocol": "tcp"
        }
      ],
      "memory": 512,
      "cpu": 256
    },
    {
      "image": "ppresto/consul-ecs:1.9.3-1.16.0-5",
      "name": "svc_hc_productapi-init",
      "essential": false,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "app-logs",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "svc_hc_productapi-init"
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
              "name": "CONFIG_FILE",
              "value": "/etc/secrets/db-creds"
          },
          {
              "name": "SERVICE_NAME",
              "value": "product-api"
          },
          {
              "name": "SERVICE_PORT",
              "value": "9090"
          },
          {
              "name": "CONSUL_SERVICE",
              "value": "true"
          },
          {
              "name": "CONSUL_SERVICE_KV_PATH",
              "value": "service/product-api/service.json"
          }
      ]
    }
  ]
  DEFINITION

  volume {
    name = "productapi"
    host_path = "/etc/secrets/db-creds"
  }

}

resource "aws_ecs_service" "svc_hc_productapi" {
  name            = "svc_hc_productapi"
  cluster         = "${module.ecs-cluster.cluster_id}"
  task_definition = "${aws_ecs_task_definition.svc_hc_productapi.arn}"
  launch_type     = "EC2"
  desired_count   = 1
  deployment_minimum_healthy_percent = 0

  network_configuration {
    subnets         = data.terraform_remote_state.vpc.outputs.public_subnets
    assign_public_ip = false
    security_groups  = [data.terraform_remote_state.consul.outputs.consul_sg, aws_security_group.postgres.id]
  }
  depends_on = ["aws_ecs_task_definition.svc_hc_postgres"]
}

resource "consul_keys" "product-api" {
  datacenter = var.aws_region
  token      = data.terraform_remote_state.consul.outputs.master_token

  # Set the CNAME of our load balancer as a key
  key {
    path  = "service/product-api/service.json"
    value    = <<VALUE
    { "service":
      { "name": "product-api",
        "token": "",
        "address": "CONTAINER_IP",
        "port": 9090,
        "tags": [
          "ecs",
          "product-api",
          "dev"
        ],
        "meta": {
        {{ range tree "service/product-api/metadata" }}
        "{{- .Key -}}":"{{- .Value -}}",
        {{ end }}
        "meta":"auto-generated-v1"
      },
        "checks": [
          {
              "id": "product-api-tcp-9090",
              "name": "Product API - TCP 9090",
              "tcp": "CONTAINER_IP:9090",
              "interval": "10s",
              "timeout": "1s",
              "DeregisterCriticalServiceAfter": "1m"

          },
          {
              "id": "product-api-http-9090",
              "name": "Product API - HTTP 9090",
              "http": "http://CONTAINER_IP:9090/coffees",
              "tls_skip_verify": true,
              "interval": "5s",
              "timeout": "2s"
          }
        ]
      }
    }
    VALUE
  }
}