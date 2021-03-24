#!/bin/bash

check_required_environment_variables()
{
  export EC2_HOST_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

  if [[ "$HTTPS" == "true" ]]; then
    if [ -z "$CONSUL_HTTP_TOKEN" ]; then
      echo "set CONSUL_HTTP_TOKEN."
      exit 1
    fi

    if [ -z "$CONSUL_CACERT" ]; then
      echo "CONSUL_CACERT will default to /consul/tls.crt."
      export CONSUL_CACERT=/consul/tls.crt
    fi

    if [ -z "$CONSUL_HTTP_ADDR" ]; then
      echo "CONSUL_HTTP_ADDR will default to EC2 Host IP."
      export CONSUL_HTTP_SSL=true
      export CONSUL_HTTP_ADDR=https://${EC2_HOST_IP}:8501
      export CONSUL_GRPC_ADDR=${EC2_HOST_IP}:8502
    fi
  else
    if [ -z "$CONSUL_HTTP_ADDR" ]; then
      echo "CONSUL_HTTP_ADDR will default to EC2 Host IP."
      export CONSUL_HTTP_SSL=false
      export CONSUL_HTTP_ADDR=http://${EC2_HOST_IP}:8500
      export CONSUL_GRPC_ADDR=${EC2_HOST_IP}:8502
    fi
  fi

  if [ -z "$CONSUL_RETRY_JOIN" ]; then
      CONSUL_RETRY_JOIN=${CONSUL_HTTP_ADDR}
  fi
}

get_server_certificate()
{
  echo "Retrieving server certificate and writing it to ${CONSUL_CACERT}."
  curl -s -k -H "X-Consul-Token:${CONSUL_HTTP_TOKEN}" ${CONSUL_HTTP_ADDR}/v1/connect/ca/roots?pem=true > ${CONSUL_CACERT}
}

set_client_configuration_secure()
{
  if [ -z "$CONSUL_CA_PEM" ]; then
    echo "set CONSUL_CA_PEM to base64 encoded contents of server ca.pem file."
    exit 1
  fi

  echo $CONSUL_CA_PEM | base64 -d > /consul/ca.pem

  echo "Decoding ca.pem to /consul/ca.pem."
  echo $CONSUL_CA_PEM | base64 -d > /consul/ca.pem

  if [ -z "$CONSUL_DATACENTER" ]; then
    echo "CONSUL_DATACENTER will default to dc1."
    CONSUL_DATACENTER="dc1"
  fi
  if [ -z "$CONSUL_GOSSIP_ENCRYPT" ]; then
    echo "set CONSUL_GOSSIP_ENCRYPT to gossip encryption key."
    exit 1
  fi

  CLIENT_CONFIG_FILE="/consul/config/client.json"
  EC2_HOST_ADDRESS=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

  echo "Using EC2 host address ${EC2_HOST_ADDRESS}."

  jq '.acl.tokens.agent = "'${CONSUL_HTTP_TOKEN}'" | 
      .datacenter = "'${CONSUL_DATACENTER}'" | 
      .encrypt = "'${CONSUL_GOSSIP_ENCRYPT}'" | 
      .advertise_addr = "'${EC2_HOST_ADDRESS}'" | 
      .retry_join = ["'${CONSUL_HTTP_ADDR}'"] |
      .auto_encrypt.ip_san = ["'${EC2_HOST_ADDRESS}'"]' ./sec_client_config.json > ${CLIENT_CONFIG_FILE}

  trap "consul leave" SIGINT SIGTERM EXIT

  consul agent -config-dir=/consul/config &

  # Block using tail so the trap will fire
  tail -f /dev/null &
  PID=$!
  wait $PID
}

set_proxy_configuration()
{
  SERVICE_CONFIG_FILE="/consul/service.json"
  CONTAINER_IP=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')

  if [ -z "$SERVICE_NAME" ]; then
    echo "set SERVICE_NAME to service name."
    exit 1
  fi

  if [ -z "$SERVICE_PORT" ]; then
    echo "set SERVICE_PORT to service port."
    exit 1
  fi

  if [ -z "$SERVICE_ID" ]; then
    echo "SERVICE_ID will default to ${SERVICE_NAME}."
    SERVICE_ID=${SERVICE_NAME}
  fi

  if [ -z "$CONSUL_SERVICE_UPSTREAMS" ]; then
    echo "CONSUL_SERVICE_UPSTREAMS will default to []."
    CONSUL_SERVICE_UPSTREAMS="[]"
  fi

  if [ -z "$SIDECAR_PORT" ]; then
    echo "SIDECAR_PORT will default to 21000."
    SIDECAR_PORT=21000
  fi

  if [ -z "$SERVICE_HEALTH_CHECK_PATH" ]; then
    echo "SERVICE_HEALTH_CHECK_PATH will default to /."
    SERVICE_HEALTH_CHECK_PATH=/
  fi

  if [ -z "$SERVICE_HEALTH_CHECK_INTERVAL" ]; then
    echo "SERVICE_HEALTH_CHECK_INTERVAL will default to 1s."
    SERVICE_HEALTH_CHECK_INTERVAL="1s"
  fi

  if [ -z "$SERVICE_HEALTH_CHECK_TIMEOUT" ]; then
    echo "SERVICE_HEALTH_CHECK_TIMEOUT will default to 1s."
    SERVICE_HEALTH_CHECK_TIMEOUT="1s"
  fi

  SERVICE_HEALTH_CHECK="http://${CONTAINER_IP}:${SERVICE_PORT}${SERVICE_HEALTH_CHECK_PATH}"
  SIDECAR_HEALTH_CHECK="${CONTAINER_IP}:${SIDECAR_PORT}"

  jq '.service.connect.sidecar_service.proxy.upstreams = '${CONSUL_SERVICE_UPSTREAMS}' | 
      .service.name = "'${SERVICE_NAME}'" | 
      .service.id = "'${SERVICE_ID}'" | 
      .service.token = "'${CONSUL_HTTP_TOKEN}'" | 
      .service.address = "'${CONTAINER_IP}'" | 
      .service.port = '${SERVICE_PORT}' | 
      .service.connect.sidecar_service.port = '${SIDECAR_PORT}' | 
      .service.check.http = "'${SERVICE_HEALTH_CHECK}'" | 
      .service.check.interval = "'${SERVICE_HEALTH_CHECK_INTERVAL}'" | 
      .service.check.timeout = "'${SERVICE_HEALTH_CHECK_TIMEOUT}'" | 
      .service.connect.sidecar_service.check.tcp = "'${SIDECAR_HEALTH_CHECK}'"' ./service_mesh_config.json > ${SERVICE_CONFIG_FILE}

  # Wait until Consul can be contacted
  until curl -s -k ${CONSUL_HTTP_ADDR}/v1/status/leader | grep 8300; do
    echo "Waiting for Consul to start at ${CONSUL_HTTP_ADDR}."
    sleep 1
  done

  echo "Registering service with consul ${SERVICE_CONFIG_FILE}."
  consul services register ${SERVICE_CONFIG_FILE}

  exit_status=$?
  if [ $exit_status -ne 0 ]; then
    echo "### Error writing service config: ${SERVICE_CONFIG_FILE} ###"
    cat $SERVICE_CONFIG_FILE
    echo ""
    exit 1
  fi

  trap "consul services deregister ${SERVICE_CONFIG_FILE}" SIGINT SIGTERM EXIT

  consul connect envoy -sidecar-for=${SERVICE_ID} &

  # Block using tail so the trap will fire
  tail -f /dev/null &
  PID=$!
  wait $PID
}

set_client_configuration()
{
  if [ -z "$CONSUL_DATACENTER" ]; then
    echo "CONSUL_DATACENTER will default to dc1."
    CONSUL_DATACENTER="dc1"
  fi

  CLIENT_CONFIG_FILE="/consul/config/client.json"
  EC2_HOST_ADDRESS=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
  RECURSERS="10.0.0.2"
  echo "Using EC2 host address ${EC2_HOST_ADDRESS}."
  TEMP="REPLACE"
  jq '.datacenter = "'${CONSUL_DATACENTER}'" |
      .advertise_addr = "'${EC2_HOST_ADDRESS}'" |
      .recursers = "'${RECURSERS}'" |
      .retry_join = ["'${TEMP}'"]' ./client_config.json > ${CLIENT_CONFIG_FILE}

  #jq doesn't handle spaces well.  using sed here.
  sed -i "s/REPLACE/${CONSUL_RETRY_JOIN}/" ${CLIENT_CONFIG_FILE}

  trap "consul leave" SIGINT SIGTERM EXIT

  consul agent -config-dir=/consul/config &

  # Block using tail so the trap will fire
  tail -f /dev/null &
  PID=$!
  wait $PID
}

write_consul_task_metadata()
{
  ECS_TASK_METADATA=$(curl -s ${ECS_CONTAINER_METADATA_URI_V4}/task | jq -re '.Containers[] | select(.DockerName | contains ("init") or contains ("internalecspause") | not)')
  KV_PATH="${1%/*}/metadata"
  echo ${ECS_TASK_METADATA} | jq -r '.DockerId' | tr -d '\n'| consul kv put ${KV_PATH}/task_dockerId -
  echo ${ECS_TASK_METADATA} | jq -r '.Image' | tr -d '\n'| consul kv put ${KV_PATH}/task_image -
  echo ${ECS_TASK_METADATA} | jq -r '.Labels."com.amazonaws.ecs.cluster"' | tr -d '\n'| consul kv put ${KV_PATH}/ecs_cluster -
  echo ${ECS_TASK_METADATA} | jq -r '.Labels."com.amazonaws.ecs.task-arn"' | tr -d '\n'| consul kv put ${KV_PATH}/task_arn -
  echo ${ECS_TASK_METADATA} | jq -r '.Labels."com.amazonaws.ecs.task-definition-version"' | tr -d '\n'| consul kv put ${KV_PATH}/task_version -
  echo ${ECS_TASK_METADATA} | jq -r '.Labels."com.amazonaws.ecs.task-definition-family"' | tr -d '\n'| consul kv put ${KV_PATH}/task_family -
  echo ${ECS_TASK_METADATA} | jq -r '.StartedAt' | tr -d '\n'| consul kv put ${KV_PATH}/task_startedAt -
  echo ${ECS_TASK_METADATA} | jq -r '.Limits.CPU' | tr -d '\n'| consul kv put ${KV_PATH}/task_cpu_limit -
  echo ${ECS_TASK_METADATA} | jq -r '.Limits.Memory' | tr -d '\n'| consul kv put ${KV_PATH}/task_mem_limit -
}
set_service_configuration()
# Service Discovery only
{
  SERVICE_CONFIG_FILE="/consul/service.json"
  SERVICE_CONFIG_FILE_CTMPL=${SERVICE_CONFIG_FILE}.ctmpl
  EC2_HOST_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

  # Wait for Metadata endpoint to be available and capture container metadata
  until curl -s ${ECS_CONTAINER_METADATA_URI_V4}/task | jq -re '.Containers[] | select(.DockerName | contains ("init") or contains ("internalecspause") | not)' | grep KnownStatus| grep RUNNING; do
    echo "Waiting for Task Metadata at ${ECS_CONTAINER_METADATA_URI_V4}/task."
    sleep 1
  done
  ECS_TASK_METADATA=$(curl -s ${ECS_CONTAINER_METADATA_URI_V4}/task | jq -re '.Containers[] | select(.DockerName | contains ("init") or contains ("internalecspause") | not)')

  if [ -z "$SERVICE_NAME" ]; then
    echo "Required: Set SERVICE_NAME to service name"
    exit 1
  fi

  if [ -z "$SERVICE_ID" ]; then
    echo "SERVICE_ID defaults to ${SERVICE_NAME}"
    SERVICE_ID=${SERVICE_NAME}
  fi

  # Discover ECS EC2 host local port mapping if SERVICE_PORT isn't set
  if [ -z "$SERVICE_PORT" ]; then
    echo "Discover Dynamic ECS SERVICE_PORT."
    SERVICE_PORT=$(echo ${ECS_TASK_METADATA} | jq -r '.Ports[].HostPort' | bc)
    if [[ $? != 0 ]]; then
      echo "No SERVICE_PORT Metadata Found..."
      curl -s ${ECS_CONTAINER_METADATA_URI_V4}/task | jq -r
      #exit 1
    else
      echo "Discovered ECS EC2 SERVICE_PORT: ${SERVICE_PORT}"
    fi
  fi

  # ECS supports Network Modes: awsvpc | bridge | host.  Identify the Mode and find the correct IP Address of the service
  NETWORK_MODE=$(echo ${ECS_TASK_METADATA} | jq -r '.Networks[].NetworkMode')
  if [[ ${NETWORK_MODE} == "awsvpc" || ${NETWORK_MODE} == "bridge" ]]; then
    CONTAINER_IP=$(echo $ECS_TASK_METADATA | jq -r '.Networks[].IPv4Addresses[0]')
  elif  [[ ${NETWORK_MODE} == "host" ]]; then
    CONTAINER_IP=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
  else
    echo "ERROR: NETWORK_MODE Unknown '${NETWORK_MODE}'"
    exit 1
  fi

  # You can use many different methods to configure your service.
  # Im centralizing all my service configuration with Consul's KV store.
  # If the Container sets CONSUL_SERVICE_KV_PATH we will attempt to read
  # the service configuration at this path from Consul's KV store at runtime.
  # This allows us to centralize our service configuration and even update service
  # configuration and metadata in real time without requiring server restarts.
  if [ ! -z "$CONSUL_SERVICE_KV_PATH" ]; then
    echo "Registering Service with kv-path: $CONSUL_SERVICE_KV_PATH"
    # Wait until Consul can be contacted
    until curl -s -k ${CONSUL_HTTP_ADDR}/v1/status/leader | grep 8300; do
      echo "Waiting for Consul to start at ${CONSUL_HTTP_ADDR}."
      sleep 1
    done

    SVC_CONFIG=$(consul kv get ${CONSUL_SERVICE_KV_PATH})
    if [[ $? == 0 ]]; then
      echo ${SVC_CONFIG} > ${SERVICE_CONFIG_FILE_CTMPL}
      sed -i "s/CONTAINER_IP/${CONTAINER_IP}/g" ${SERVICE_CONFIG_FILE_CTMPL}
      sed -i "s/EC2_HOST_IP/${EC2_HOST_IP}/g" ${SERVICE_CONFIG_FILE_CTMPL}
      sed -i "s/SERVICE_PORT/${SERVICE_PORT}/g" ${SERVICE_CONFIG_FILE_CTMPL}

      write_consul_task_metadata ${CONSUL_SERVICE_KV_PATH}

     # consul-template can be used to once or in daemon mode to pull kv data in real time.
     # This will build our service.json configuration with the latest metadata
      consul-template -template "${SERVICE_CONFIG_FILE_CTMPL}:${SERVICE_CONFIG_FILE}" -once
    else
      echo "consul kv get ${CONSUL_SERVICE_KV_PATH} Not Found"
      consul kv get ${CONSUL_SERVICE_KV_PATH}
      #exit 1
    fi
  else
    if [ -z "$SERVICE_HEALTH_CHECK_PATH" ]; then
      echo "SERVICE_HEALTH_CHECK_PATH will default to /."
      SERVICE_HEALTH_CHECK_PATH=/
    fi
    if [ -z "$SERVICE_HEALTH_CHECK_INTERVAL" ]; then
      echo "SERVICE_HEALTH_CHECK_INTERVAL will default to 1s."
      SERVICE_HEALTH_CHECK_INTERVAL="5s"
    fi
    if [ -z "$SERVICE_HEALTH_CHECK_TIMEOUT" ]; then
      echo "SERVICE_HEALTH_CHECK_TIMEOUT will default to 1s."
      SERVICE_HEALTH_CHECK_TIMEOUT="1s"
    fi
    SERVICE_HEALTH_CHECK="http://${CONTAINER_IP}:${SERVICE_PORT}${SERVICE_HEALTH_CHECK_PATH}"

    jq '.service.name = "'${SERVICE_NAME}'" | 
        .service.id = "'${SERVICE_ID}'" | 
        .service.address = "'${CONTAINER_IP}'" | 
        .service.port = '${SERVICE_PORT}' | 
        .service.check.http = "'${SERVICE_HEALTH_CHECK}'" | 
        .service.check.interval = "'${SERVICE_HEALTH_CHECK_INTERVAL}'" | 
        .service.check.timeout = "'${SERVICE_HEALTH_CHECK_TIMEOUT}'"' ./service_config.json > ${SERVICE_CONFIG_FILE}
  fi

  # Wait until Consul can be contacted
  until curl -s -k ${CONSUL_HTTP_ADDR}/v1/status/leader | grep 8300; do
    echo "Waiting for Consul to start at ${CONSUL_HTTP_ADDR}."
    sleep 1
  done

  echo "Registering service with consul ${SERVICE_CONFIG_FILE}."
  consul services register ${SERVICE_CONFIG_FILE}

  exit_status=$?
  if [ $exit_status -ne 0 ]; then
    echo "### Error writing service config: ${SERVICE_CONFIG_FILE} ###"
    cat $SERVICE_CONFIG_FILE
    echo ""
    #exit 1
  fi

    echo "ECS TASK METADATA"
    echo $ECS_TASK_METADATA | jq -r
    echo "$SERVICE_CONFIG_FILE"
    cat $SERVICE_CONFIG_FILE

    sleep 3600
}

check_required_environment_variables

if [[ "$HTTPS" == "true" ]]; then

  get_server_certificate
  if [ ! -z "$CONSUL_CLIENT" ]; then
    echo "Starting Consul client."
    set_secure_client_configuration
  fi

  if [ ! -z "$CONSUL_PROXY" ]; then
    echo "Starting Consul proxy."
    set_proxy_configuration
  fi

else
  if [ ! -z "$CONSUL_CLIENT" ]; then
    echo "Starting Consul client."
    set_client_configuration
  fi

  if [ ! -z "$CONSUL_SERVICE" ]; then
    echo "Registering Service."
    set_service_configuration
  fi

fi