#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Troubleshooting
# /var/log/cloud-init-output.log
# /var/lib/cloud/instances/$INSTANCE_ID
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
AVAILABILITY_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
LOCAL_IPV4=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4`

echo "Installing pre-requisites...."
apt-get update
apt-get install jq unzip wget -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

install_from_zip() {
  cd /tmp && {
    if [[ ! -f consul_${CONSUL_VER}+ent_linux_amd64.zip ]]; then
        curl -O https://releases.hashicorp.com/consul/${CONSUL_VER}+ent/consul_${CONSUL_VER}+ent_linux_amd64.zip
        mv consul_${CONSUL_VER}+ent_linux_amd64.zip consul.zip
    fi
    unzip -qq "consul.zip"
    sudo mv "consul" "/usr/local/bin/consul"
    sudo chmod +x "/usr/local/bin/consul"
    rm -rf "consul.zip"
  }
}

echo "Adding Consul system users"

create_ids() {
  sudo /usr/sbin/groupadd --force --system consul
  if ! getent passwd consul >/dev/null ; then
    sudo /usr/sbin/adduser \
      --system \
      --home /srv/consul \
      --no-create-home \
      --shell /bin/false \
      consul  >/dev/null
  fi
}

create_ids consul

echo "Configuring HashiCorp directories"
# Second argument specifies user/group for chown, as consul-snapshot does not have a corresponding user
directory_setup() {
  # create and manage permissions on directories
  sudo mkdir -pm 0750 /etc/consul.d /opt/consul /opt/consul/data
  sudo mkdir -pm 0700 /opt/consul/tls
  sudo chown -R consul:consul /etc/consul.d /opt/consul
}

install_from_zip consul
directory_setup consul consul

# Create Consul Client Configuration
cat << EOF > /etc/consul.d/consul.hcl
datacenter          = "${datacenter}"
server              = false
data_dir            = "/opt/consul/data"
bind_addr           = "$${LOCAL_IPV4}"
client_addr         = "0.0.0.0"
log_level           = "INFO"
node_name           = "$${INSTANCE_ID}"
ui                  = true

# AWS cloud join
retry_join          = ["provider=aws tag_key=Environment-Name tag_value=${environment_name}"]
EOF

# Create Service Registration
echo '{
  "service": {
    "name": "ec2-bastion-svc",
    "tags": [
      "service",
      "bastion",
      "ec2"
    ],
    "meta": {
      "env": "production",
      "ver": "1.0",
      "ttl": "24h"
    },
    "port": 80
  }
}' > /etc/consul.d/ec2-bastion-svc.json

# Systemd Service
cat << EOF > /tmp/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/usr/local/bin/consul reload
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo cp /tmp/consul.service /etc/systemd/system/
sudo chmod 0664 /etc/systemd/system/consul.service

systemctl enable consul
systemctl start consul

echo "Setup Consul profile"
cat <<PROFILE | sudo tee /etc/profile.d/consul.sh
export CONSUL_ADDR=http://127.0.0.1:8500
export CONSUL_HTTP_TOKEN=c1c8dd28-ba9c-7bd0-edde-b63962b736b2
PROFILE