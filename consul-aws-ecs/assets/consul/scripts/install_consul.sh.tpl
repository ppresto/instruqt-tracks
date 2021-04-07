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
apt-get install jq unzip wget docker.io -y

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

%{ if enable_acl_system }
cat << EOF > /etc/consul.d/acl.hcl
acl = {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
  tokens = {
    agent = "${agent_server_token}"
  }
}
EOF
%{ endif }

%{ if enable_gossip_encryption }
cat << EOF > /etc/consul.d/encrypt_gossip.hcl
encrypt = "${gossip_key}"
EOF
%{ endif }

%{ if enable_tls }
echo "${consul_ca_cert}" > /opt/consul/tls/ca-cert.pem

cat << EOF > /etc/consul.d/tls.hcl
verify_incoming        = false
verify_outgoing        = true
verify_server_hostname = true
ca_file                = "/opt/consul/tls/ca-cert.pem"
auto_encrypt {
  tls = true
}
ports {
  https = 8501
}
EOF
%{ endif }

# Create Service Registration
echo '{
  "service": {
    "name": "ec2-bastion-svc",
    "token": "",
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

echo "Setup Consul profile"
cat <<PROFILE | sudo tee /etc/profile.d/consul.sh
export CONSUL_HTTP_ADDR=${consul_url}
export CONSUL_HTTP_TOKEN=${master_token}
export VAULT_HTTP_ADDR=${vault_url}
export VAULT_TOKEN="root"
PROFILE

#
### Install Vault CLI
#
echo "installing vault..."
cd /tmp && {
  if [[ ! -f vault_1.6.3_linux_amd64.zip ]]; then
      curl -O https://releases.hashicorp.com/vault/1.6.3/vault_1.6.3_linux_amd64.zip
      mv vault_1.6.3_linux_amd64.zip vault.zip
  fi
  unzip -qq "vault.zip"
  sudo mv "vault" "/usr/local/bin/vault"
  sudo chmod +x "/usr/local/bin/vault"
  rm -rf "vault.zip"
}

#
### Run Vault Server using docker-compose
#
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

sudo cat <<-EOF > /docker-compose.yml
version: '3'
services:
  vault:
    container_name: vault
    network_mode: host
    restart: always
    image: vault
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=root
EOF

#
### Installing Consul Template
#
echo "installing consul-template..."
cd /tmp && {
  if [[ ! -f consul-template_0.25.2_linux_amd64.tgz ]]; then
      curl -O https://releases.hashicorp.com/consul-template/0.25.2/consul-template_0.25.2_linux_amd64.tgz
  fi
  tar -zxf consul-template_0.25.2_linux_amd64.tgz
  sudo mv consul-template /usr/local/bin/consul-template
  sudo chmod 0755 /usr/local/bin/consul-template
  rm consul-template_0.25.2_linux_amd64.tgz
}

/usr/local/bin/docker-compose up -d

#consul-template \
#-consul-addr "${consul_url}" \
#-vault-addr "${vault_url}" \
#-template "/etc/consul.d/ec2-bastion-svc.json.ctmpl:/etc/consul.d/ec2-bastion-svc.json" \
#-exec "systemctl start consul"

systemctl start consul