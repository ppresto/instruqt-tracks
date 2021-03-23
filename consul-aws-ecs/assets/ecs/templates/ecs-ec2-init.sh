#!/bin/bash

yum update -y
yum install bind-utils dnsmasq -y

cat <<-'EOF' > /etc/dnsmasq.d/consul.conf
# Listen on docker interface
interface=docker0

# Enable forward lookup of the 'consul' domain:
server=/consul/127.0.0.1#8600

# Accept DNS queries only from hosts whose address is on a local subnet.
#local-service

# Don't poll /etc/resolv.conf for changes.
no-poll

# Don't read /etc/resolv.conf. Get upstream servers only from the command
# line or the dnsmasq configuration file (see the "server" directive below).
no-resolv

# Specify IP address(es) of other DNS servers for queries not handled
# directly by consul. There is normally one 'server' entry set for every
# 'nameserver' parameter found in '/etc/resolv.conf'. See dnsmasq(8)'s
# 'server' configuration option for details.
server=10.0.0.2

# Set the size of dnsmasq's cache. The default is 150 names. Setting the
# cache size to zero disables caching.
#cache-size=65536

# Uncomment and modify as appropriate to enable reverse DNS lookups for
# common netblocks found in RFC 1918, 5735, and 6598:
#rev-server=0.0.0.0/8,127.0.0.1#8600
#rev-server=10.0.0.0/8,127.0.0.1#8600
EOF

# Remove AWS DNS Server from resolv.conf
sed -i s"/^\(nameserver.*\)/#\1/" /etc/resolv.conf

# Start dnsmasq systemd
systemctl enable dnsmasq
systemctl start dnsmasq

# Disabled in favor of configuring dnsServer in each task definition
# Configure Docker Daemon to route DNS requests to local host of default bridge network
#sed -i "s/OPTIONS=\"\(.*\)\"/OPTIONS=\"\1 --dns 172.17.0.1\"/" /etc/sysconfig/docker
#systemctl restart docker

# ECS Cluster
echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config
echo ECS_INSTANCE_ATTRIBUTES={\"purchase-option\":\"spot\"} >> /etc/ecs/ecs.config
#echo ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true >> /etc/ecs/ecs.config
#echo ECS_ENABLE_TASK_ENI=true >> /etc/ecs/ecs.config

#
#  Create Local Config for frontend to mount
#
mkdir -p /etc/nginx/conf.d
cat <<-'EOF' > /etc/nginx/conf.d/default.conf
# /etc/nginx/conf.d/default.conf
resolver 172.17.0.1 valid=10s ipv6=off;
#error_log /var/log/nginx/error.log debug;

upstream backend {
    zone upstream_backend 64k;
    server service.consul service=pub-api resolve;
}
server {
    listen       80;
    server_name  localhost;
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    location /api {
        proxy_pass http://backend;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF

#
#  Create Local Config for product-api to mount
#

mkdir -p /etc/secrets
cat <<-EOF > /etc/secrets/db-creds
{
"db_connection": "host=postgres.service.consul port=5432 user=postgres password=password dbname=products sslmode=disable",
  "bind_address": ":9090",
  "metrics_address": ":9103"
}
EOF
