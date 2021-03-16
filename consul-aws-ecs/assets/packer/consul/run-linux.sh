#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PACKER_VER=1.5.4
CONSUL_VER=1.8.0
RELEASE=0.0.2

# Build Latest Consul Ent Binary and update AMI Release
#CONSUL_VER=1.9.3
#RELEASE=0.0.3

packer_cur_ver=$(packer version | head -1 | awk '{ print $NF}' | sed "s/^v//")
if [[ ${packer_cur_ver} != ${PACKER_VER} ]]; then
  echo "installing packer..."
  curl -O https://releases.hashicorp.com/packer/${PACKER_VER}/packer_${PACKER_VER}_linux_amd64.zip
  unzip packer_${PACKER_VER}_linux_amd64.zip
  mv packer /usr/local/bin/packer
  rm -f *.zip
else
  echo "Packer: v${PACKER_VER} Already Exists"
fi


#Download Consul
if [[ ! -f consul_${CONSUL_VER}+ent_linux_amd64.zip ]]; then
  curl -O https://releases.hashicorp.com/consul/${CONSUL_VER}+ent/consul_${CONSUL_VER}+ent_linux_amd64.zip
fi

#create variable file
pubkey=$(cat ~/.ssh/id_rsa.pub)
cat <<- EOF > vars.json
{
  "consul_zip": "consul_${CONSUL_VER}+ent_linux_amd64.zip",
  "consul_version": "${CONSUL_VER}",
  "username": "ppresto",
  "pubkey": "${pubkey}",
  "owner": "ppresto@hashicorp.com",
  "release": "${RELEASE}"
}
EOF

AWS_REGION=$(terraform output -state=${DIR}/../../vpc/terraform.tfstate aws_region)
AWS_REGION=${AWS_REGION} packer build -var-file vars.json centos.json

# Verify Image was created with aws-cli

#aws ec2 describe-images --region ${AWS_REGION} \
#--filters "Name=tag:Owner,Values=ppresto@hashicorp.com" \
#--query 'Images[*].[ImageId]' --output text
