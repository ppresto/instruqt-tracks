ARG ENVOY_VERSION

FROM envoyproxy/envoy-alpine:v${ENVOY_VERSION}

ARG CONSUL_VERSION

RUN apk add -u bash curl jq bind-tools && \
    wget https://releases.hashicorp.com/consul/"${CONSUL_VERSION}"/consul_"${CONSUL_VERSION}"_linux_amd64.zip \
	-O /tmp/consul.zip && \
    unzip /tmp/consul.zip -d /tmp && \
    mv /tmp/consul /usr/local/bin/consul && \
    rm -f /tmp/consul.zip && \
    mkdir -p /consul/config && \
    mkdir -p /consul/data
RUN curl -O https://releases.hashicorp.com/consul-template/0.25.2/consul-template_0.25.2_linux_amd64.tgz && \
    tar -zxf consul-template_0.25.2_linux_amd64.tgz && \
    mv consul-template /usr/local/bin/consul-template && \
    rm consul-template_0.25.2_linux_amd64.tgz && \
    chmod 0755 /usr/local/bin/consul-template

COPY ./entrypoint.sh /entrypoint.sh
COPY ./client_config.json /client_config.json
COPY ./sec_client_config.json /sec_client_config.json
COPY ./service_config.json /service_config.json
COPY ./service_mesh_config.json /service_mesh_config.json
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
