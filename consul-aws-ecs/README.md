# Shutterfly POC

## AWS CLI Cheatsheet
```
# Get ASG Name matching "presto"
asg=$(aws autoscaling describe-auto-scaling-groups | jq -r '.AutoScalingGroups[] | select(.AutoScalingGroupName | test("presto"))| .AutoScalingGroupName')

# get Launch config mating "presto"
lc=$(aws autoscaling describe-launch-configurations | jq -r '.LaunchConfigurations[] | select(.LaunchConfigurationName | test("presto")) | .LaunchConfigurationName')

# Scale ASG by increasing min-size +1
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${asg} --launch-configuration-name ${lc} --min-size 2 --max-size 3

# Get ECS Cluster ARN
ecs_cluster=$(aws ecs describe-clusters --clusters ecs-vpc-presto | jq -r '.clusters[].clusterArn')

# Update ECS Task Definition (frontend)
aws ecs update-service --cluster ${ecs_cluster} --service svc_hc_frontend --desired-count 4

# Update ECS Task Definition (pub-api)
aws ecs update-service --cluster ${ecs_cluster} --service svc_hc_pubapi --desired-count 4

```

### Hashicups Microservice Troubleshooting
```
#frontend
curl http://frontend.service.consul
curl -X POST -H 'Content-type: application/json' -H 'Cache-Control: no-cache' --data '{"query":"{coffees{id name image price teaser description}}"}' http://frontend.service.consul:80/api

# find pub-api using SRV and dns host 172.17.0.1
nslookup -query=SRV _pub-api._tcp.service.consul 172.17.0.1

#pub-api
curl -X POST -H 'Content-type: application/json' --data '{"query":"{coffees{id name image price teaser description}}"}' http://pub-api.service.consul:8080/api

#product-api
curl http://product-api.service.consul:9090/coffees
```

### Consul API Commands
```
# List services
curl -s -X GET http://consul-lb-135321ca0133070a.elb.us-west-2.amazonaws.com/v1/catalog/services | jq -r keys

# list services in ecs_cluster
curl -s -X GET http://consul-lb-135321ca0133070a.elb.us-west-2.amazonaws.com/v1/catalog/services --data-urlencode 'filter=Meta.ecs_cluster == "ecs-vpc-presto"'

# List services with image matching frontend:v0.0.1
curl -s -X GET http://consul-lb-135321ca0133070a.elb.us-west-2.amazonaws.com/v1/catalog/services --data-urlencode 'filter=Meta.task_image == "ppresto/frontend:v0.0.1"
```