#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

###!/usr/bin/env bash

echo "Starting deployment from AMI: ${ami}"
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
AVAILABILITY_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
LOCAL_IPV4=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4`

cat << EOF > /etc/consul.d/consul.hcl
datacenter          = "${datacenter}"
server              = true
bootstrap_expect    = ${bootstrap_expect}
data_dir            = "/opt/consul/data"
advertise_addr      = "$${LOCAL_IPV4}"
client_addr         = "0.0.0.0"
log_level           = "INFO"
ui                  = true
dns_config {
    enable_truncate = true
}

# AWS cloud join
retry_join          = ["provider=aws tag_key=Environment-Name tag_value=${environment_name}-consul"]

# Max connections for the HTTP API
limits {
  http_max_conns_per_client = 128
}
%{ if performance_mode }
performance {
    raft_multiplier = 1
}%{ endif }
EOF

%{ if enable_gossip_encryption }
cat << EOF > /etc/consul.d/encrypt_gossip.hcl
encrypt = "${gossip_key}"
EOF
%{ endif }

cat << EOF > /etc/consul.d/autopilot.hcl
autopilot {%{ if redundancy_zones }
  redundancy_zone_tag = "az"%{ endif }
  upgrade_version_tag = "consul_cluster_version"
}
EOF
 %{ if redundancy_zones }
cat << EOF > /etc/consul.d/redundancy_zone.hcl
node_meta = {
    az = "$${AVAILABILITY_ZONE}"
}
EOF
%{ endif }

cat << EOF > /etc/consul.d/cluster_version.hcl
node_meta = {
    consul_cluster_version = "${consul_cluster_version}"
}
EOF

%{ if enable_tls }
echo "${consul_ca_cert}" > /opt/consul/tls/ca-cert.pem
echo "${consul_cert}" > /opt/consul/tls/server-cert.pem
echo "${consul_key}" > /opt/consul/tls/server-key.pem

cat << EOF > /etc/consul.d/tls.hcl
verify_incoming_rpc    = true
verify_outgoing        = true
verify_server_hostname = true
ca_file   = "/opt/consul/tls/ca-cert.pem"
cert_file = "/opt/consul/tls/server-cert.pem"
key_file  = "/opt/consul/tls/server-key.pem"
auto_encrypt {
  allow_tls = true
}

ports {
  https = 8501
}
EOF
%{ endif }

%{ if ! enable_acl_system }
  mkdir -p /etc/consul.d/tmp
  acl_config_file=/etc/consul.d/tmp/acl.hcl
%{ else } 
  acl_config_file=/etc/consul.d/acl.hcl
%{ endif }

cat << EOF > $${acl_config_file}
acl {
  enabled        = true
  default_policy = "${acl_system_default_policy}"
  enable_token_persistence = true
  tokens {
    master = "${master_token}"
    agent  = "${agent_server_token}"
  }
}
EOF

%{ if enable_connect }
cat << EOF > /etc/consul.d/connect.hcl
connect {
  enabled = true
}
EOF
%{ endif }

%{ if consul_config != {} }
cat << EOF > /etc/consul.d/zz-override.json
${jsonencode(consul_config)}
EOF
%{ endif }

cat << EOF > /tmp/bootstrap_tokens.sh
#!/bin/bash -e
export CONSUL_HTTP_TOKEN=${master_token}
echo "Creating Consul ACL policies......"
if ! consul kv get acl_bootstrap 2>/dev/null; then

  echo '
  node_prefix "" {
    policy = "write"
  }
  service_prefix "" {
    policy = "read"
  }
  service "consul" {
    policy = "write"
  }
  agent_prefix "" {
    policy = "write"
  }' | consul acl policy create -name consul-agent-server -rules -

  echo '
  acl = "write"
  key "consul-snapshot/lock" {
  policy = "write"
  }
  session_prefix "" {
  policy = "write"
  }
  service "consul-snapshot" {
  policy = "write"
  }' | consul acl policy create -name snapshot_agent -rules -

  echo '
  node_prefix "" {
    policy = "read"
  }
  service_prefix "" {
    policy = "read"
  }
  session_prefix "" {
    policy = "read"
  }
  agent_prefix "" {
    policy = "read"
  }
  query_prefix "" {
    policy = "read"
  }
  operator = "read"' |  consul acl policy create -name anonymous -rules -

  consul acl token create -description "consul agent server token" -policy-name consul-agent-server -secret "${agent_server_token}" 1>/dev/null
  consul acl token create -description "consul snapshot agent" -policy-name snapshot_agent -secret "${snapshot_token}" 1>/dev/null
  consul acl token update -id anonymous -policy-name anonymous 1>/dev/null

  consul kv put  acl_bootstrap 1
else
  echo "Bootstrap already completed"
fi
EOF

chmod 755 /tmp/bootstrap_tokens.sh

%{ if enable_snapshots }
cat << EOF > /etc/consul-snapshot.d/consul-snapshot.json
{
	"snapshot_agent": {
		"http_addr": "127.0.0.1:8500",
		"token": "${snapshot_token}",
		"datacenter": "${datacenter}",
		"snapshot": {
			"interval": "${snapshot_interval}",
			"retain": ${snapshot_retention},
			"deregister_after": "8h"
		},
		"aws_storage": {
			"s3_region": "${datacenter}",
			"s3_bucket": "${environment_name}-consul-data"
		}
	}
}
EOF
chown -R consul:consul /etc/consul-snapshot.d/*
chmod -R 600 /etc/consul-snapshot.d/*
%{ endif }

chown -R consul:consul /etc/consul.d
chmod -R 640 /etc/consul.d/*

systemctl daemon-reload
systemctl enable consul
systemctl start consul

# Wait for consul-kv to come online
while true; do
    curl -s http://127.0.0.1:8500/v1/catalog/service/consul | jq -e . && break
    sleep 5
done

# Setup ACL Policies (note: required to read NodeMeta data below)
%{ if enable_acl_system }
NEXT_WAIT_TIME=0
until [ $NEXT_WAIT_TIME -eq 10 ] || curl -s http://127.0.0.1:8500/v1/agent/self | jq -r '.Stats.consul.leader_addr'|grep "10.0"; do
    echo "Waiting $((NEXT_WAIT_TIME+1)) sec for $(terraform output dns_name)"
    sleep $(( NEXT_WAIT_TIME++ ))
done
sleep 30
/tmp/bootstrap_tokens.sh
%{ endif }

# Wait until all new node versions are online
until [[ $TOTAL_NEW -ge ${total_nodes} ]]; do
    TOTAL_NEW=`curl -s http://127.0.0.1:8500/v1/catalog/service/consul | jq -er 'map(select(.NodeMeta.consul_cluster_version == "${consul_cluster_version}")) | length'`
    sleep 5
    echo "Current New Node Count: $TOTAL_NEW"
done

# Wait for a leader
until [[ $LEADER -eq 1 ]]; do
    let LEADER=0
    echo "Fetching new node ID's"
    NEW_NODE_IDS=`curl -s http://127.0.0.1:8500/v1/catalog/service/consul | jq -r 'map(select(.NodeMeta.consul_cluster_version == "${consul_cluster_version}")) | .[].ID'`
    # Wait until all new nodes are voting
    until [[ $VOTERS -ge ${bootstrap_expect} ]]; do
        let VOTERS=0
        for ID in $NEW_NODE_IDS; do
            echo "Checking $ID"
            curl -s http://127.0.0.1:8500/v1/operator/autopilot/health | jq -e ".Servers[] | select(.ID == \"$ID\" and .Voter == true)" && let "VOTERS+=1" && echo "Current Voters: $VOTERS"
            sleep 2
        done
    done
    echo "Checking Old Nodes"
    OLD_NODES=`curl -s http://127.0.0.1:8500/v1/catalog/service/consul | jq -er 'map(select(.NodeMeta.consul_cluster_version != "${consul_cluster_version}")) | length'`
    echo "Current Old Node Count: $OLD_NODES"
    # Wait for old nodes to drop from voting
    until [[ $OLD_NODES -eq 0 ]]; do
        OLD_NODES=`curl -s http://127.0.0.1:8500/v1/catalog/service/consul | jq -er 'map(select(.NodeMeta.consul_cluster_version != "${consul_cluster_version}")) | length'`
        OLD_NODE_IDS=`curl -s http://127.0.0.1:8500/v1/catalog/service/consul | jq -r 'map(select(.NodeMeta.consul_cluster_version != "${consul_cluster_version}")) | .[].ID'`
        for ID in $OLD_NODE_IDS; do
            echo "Checking Old $ID"
            curl -s http://127.0.0.1:8500/v1/operator/autopilot/health | jq -e ".Servers[] | select(.ID == \"$ID\" and .Voter == false)" && let "OLD_NODES-=1" && echo "Checking Old Nodes for Voters: $OLD_NODES"
            sleep 2
        done
    done
    # Check if there is a leader running the newest version
    LEADER_ID=`curl -s http://127.0.0.1:8500/v1/operator/autopilot/health | jq -er ".Servers[] | select(.Leader == true) | .ID"`
    curl -s http://127.0.0.1:8500/v1/catalog/service/consul | jq -er ".[] | select(.ID == \"$LEADER_ID\" and .NodeMeta.consul_cluster_version == \"${consul_cluster_version}\")" && let "LEADER+=1" && echo "New Leader: $LEADER_ID"
    sleep 2
done

echo "$INSTANCE_ID determined all nodes to be healthy and ready to go <3"

%{ if enable_snapshots }
systemctl enable consul-snapshot
systemctl start consul-snapshot
%{ endif }

while true; do
    aws autoscaling complete-lifecycle-action --lifecycle-action-result CONTINUE --instance-id $INSTANCE_ID --lifecycle-hook-name consul_health --auto-scaling-group-name "${asg_name}" --region ${datacenter} && break
    # Sleep for AWS race condition
    sleep 5
done
