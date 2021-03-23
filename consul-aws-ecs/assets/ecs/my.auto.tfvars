cluster_name = "ecs-vpc-presto"
aws_region = "us-west-2"
ssh_key_name = "instruqt"
consul_ecs_agent_image_name = "ppresto/consul-ecs:1.9.3-1.16.0-5"
min_spot_instances = 1
max_spot_instances = 3