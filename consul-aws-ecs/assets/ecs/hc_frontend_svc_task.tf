resource "aws_ecs_task_definition" "svc_hc_frontend" {
  family                   = "svc_hc_frontend"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = "${module.ecs-cluster.ecs_instance_role_arn}"
  task_role_arn            = "${module.ecs-cluster.ecs_instance_role_arn}"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "svc_hc_frontend",
      "image": "ppresto/frontend:v0.0.1",
      "dnsServers": ["172.17.0.1","10.0.0.2"],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "app-logs",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "svc_hc_frontend"
        }
      },
      "mountPoints" : [
        {
            "containerPath" : "/etc/nginx/conf.d/",
            "sourceVolume" : "frontend",
            "readOnly": true
        }
      ],
      "portMappings": [
        {
          "containerPort": 80
        }
      ],
      "memory": 512,
      "cpu": 256
    },
    {
      "image": "${var.consul_ecs_agent_image_name}",
      "name": "svc_hc_frontend-init",
      "dnsServers": ["172.17.0.1","10.0.0.2"],
      "essential": false,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "app-logs",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "svc_hc_frontend-init"
        }
      },
      "environment": [
          {
              "name": "SERVICE_NAME",
              "value": "frontend"
          },
          {
              "name": "CONSUL_SERVICE",
              "value": "true"
          },
          {
              "name": "CONSUL_SERVICE_KV_PATH",
              "value": "service/frontend/service.json"
          },
          {
              "name": "VAULT_ADDR",
              "value": "${data.terraform_remote_state.consul.outputs.env}"
          }
      ]
    }
  ]
  DEFINITION

  volume {
    name = "frontend"
    host_path = "/etc/nginx/conf.d/"
  }
}

resource "aws_ecs_service" "svc_hc_frontend" {
  name            = "svc_hc_frontend"
  cluster         = "${module.ecs-cluster.cluster_id}"
  task_definition = "${aws_ecs_task_definition.svc_hc_frontend.arn}"
  launch_type     = "EC2"
  desired_count   = 1
  deployment_minimum_healthy_percent = 0
  force_new_deployment = true

  load_balancer {
    target_group_arn = "${aws_lb_target_group.lb_tg_frontend.arn}" # Referencing our target group
    container_name   = "${aws_ecs_task_definition.svc_hc_frontend.family}"
    container_port   = 80 # Specifying the container port
  }
  depends_on              = ["aws_lb_listener.listener_frontend"]
}

resource "consul_keys" "frontend" {
  datacenter = var.aws_region
  token      = data.terraform_remote_state.consul.outputs.master_token

  # Set the CNAME of our load balancer as a key
  key {
    path  = "service/frontend/service.json"
    value    = <<VALUE
    { "service":
      { "name": "frontend",
        "id": "frontend-SERVICE_PORT",
        "token": "",
        "address": "EC2_HOST_IP",
        "port": SERVICE_PORT,
        "tags": [
            "ecs",
            "frontend",
            "dev"
          ],
          "meta": {
            {{ range tree "service/frontend/metadata" }}
            "{{- .Key -}}":"{{- .Value -}}",
            {{ end }}
            "meta":"auto-generated-v1"
          },
          "checks": [
            {
                "id": "frontend-tcp-80-SERVICE_PORT",
                "name": "Container TCP Port - 80",
                "tcp": "CONTAINER_IP:80",
                "interval": "10s",
                "timeout": "2s",
                "DeregisterCriticalServiceAfter": "1m"
            },
            {
                "id": "frontend-http-80-SERVICE_PORT",
                "name": "Nginx Gateway - 80",
                "http": "http://CONTAINER_IP:80/api",
                "tls_skip_verify": true,
                "method": "POST",
                "header": {"Content-Type": ["application/json"]},
                "body": "{\"query\":\"{coffees{id name image price teaser description}}\"}",
                "interval": "5s",
                "timeout": "2s"
            },
            {
                "id": "frontend-tcp-ec2-SERVICE_PORT",
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