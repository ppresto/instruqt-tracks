# Shutterfly POC

## AWS CLI Cheatsheet
```
# Get ASG Name matching "presto"
asg=$(aws autoscaling describe-auto-scaling-groups | jq -r '.AutoScalingGroups[] | select(.AutoScalingGroupName | test("presto"))| .AutoScalingGroupName')

# get Launch config mating "presto"
lc=$(aws autoscaling describe-launch-configurations | jq -r '.LaunchConfigurations[] | select(.LaunchConfigurationName | test("presto")) | .LaunchConfigurationName')

# Scale ASG by increasing min-size +1
aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${asg} --launch-configuration-name ${lc} --min-size  2 --max-size 3

# Update ECS Tasks in Service
aws ecs update-service --service svc_hc_frontend --desired-count 4

# Get ECS Cluster ARN
ecs_cluster=$(aws ecs describe-clusters --clusters ecs-vpc-presto | jq -r '.clusters[].clusterArn')

# Update ECS Task Definition
aws ecs update-service --cluster ${ecs_cluster} --service svc_hc_frontend --desired-count 4
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