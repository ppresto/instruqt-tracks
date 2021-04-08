resource "aws_ecs_task_definition" "consul-client" {
  family                   = "consul-client"
  requires_compatibilities = ["EC2"]
  network_mode             = "host"    # Using awsvpc as our network mode as this is required for Fargate
  #memory                   = 128         # Specifying the memory our container requires
  #cpu                      = 10         # Specifying the CPU our container requires
  execution_role_arn       = "${module.ecs-cluster.ecs_instance_role_arn}"
  task_role_arn            = "${module.ecs-cluster.ecs_instance_role_arn}"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "consul-client",
      "image": "ppresto/consul-ecs:1.9.3-1.16.0-6",
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "app-logs",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "consul"
        }
      },
      "portMappings": [
        {
          "hostPort": 8301,
          "protocol": "tcp",
          "containerPort": 8301
        },
        {
          "hostPort": 8301,
          "protocol": "udp",
          "containerPort": 8301
        },
        {
          "hostPort": 8302,
          "protocol": "tcp",
          "containerPort": 8302
        },
        {
          "hostPort": 8300,
          "protocol": "tcp",
          "containerPort": 8300
        },
        {
          "hostPort": 8600,
          "protocol": "tcp",
          "containerPort": 8600
        },
        {
          "hostPort": 8600,
          "protocol": "udp",
          "containerPort": 8600
        },
        {
          "hostPort": 8501,
          "protocol": "tcp",
          "containerPort": 8501
        },
        {
          "hostPort": 8502,
          "protocol": "tcp",
          "containerPort": 8502
        }
      ],
      "memory": 128,
      "cpu": 10,
      "environment": [
        {
          "name": "CONSUL_DATACENTER",
          "value": "us-west-2"
        },
        {
          "name": "CONSUL_CLIENT_SEC",
          "value": "true"
        },
        {
          "name": "CONSUL_RETRY_JOIN",
          "value": "provider=aws tag_key=Environment-Name tag_value=${data.terraform_remote_state.consul.outputs.env}-consul"
        },
        {
          "name": "VAULT_ADDR",
          "value": "http://${data.terraform_remote_state.consul.outputs.vault_url}"
        },
        {
          "name": "CONSUL_CA_PEM",
          "value": "${data.terraform_remote_state.consul.outputs.ca}"
        },
        {
          "name": "CONSUL_GOSSIP_ENCRYPT",
          "value": "${data.terraform_remote_state.consul.outputs.gossip_key}"
        },
        {
          "name": "AGENT_SERVER_TOKEN",
          "value": "${data.terraform_remote_state.consul.outputs.agent_server_token}"
        }
      ]
    }
  ]
  DEFINITION
}

resource "aws_ecs_service" "consul-client-svc" {
  name            = "consul-client-svc"
  cluster         = "${module.ecs-cluster.cluster_id}"
  task_definition = "${aws_ecs_task_definition.consul-client.arn}"
  scheduling_strategy = "DAEMON"

  placement_constraints {
    type = "distinctInstance"
  }
}

# seed some meta data for services to read and add dynamically.
resource "consul_keys" "meta" {
  datacenter = var.aws_region
  token      = data.terraform_remote_state.consul.outputs.master_token

  # Set the CNAME of our load balancer as a key
  key {
    path  = "meta/env"
    value    = "dev"
  }
}