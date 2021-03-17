BUILD_ID := $(shell git rev-parse --short HEAD 2>/dev/null || echo no-commit-id)
DOCKER_ID := ppresto
IMAGE_NAME := ${DOCKER_ID}/consul-ecs
ENVOY_VERSION := 1.16.0
CONSUL_VERSION := 1.9.3
PATCH_VERSION := 5
VERSION := $(CONSUL_VERSION)-$(ENVOY_VERSION)-$(PATCH_VERSION)

.DEFAULT_GOAL := help
help: ## List targets & descriptions
	@cat Makefile* | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## Build docker image
	docker build --build-arg CONSUL_VERSION=$(CONSUL_VERSION) --build-arg ENVOY_VERSION=$(ENVOY_VERSION) -t $(IMAGE_NAME):$(VERSION) .
	docker tag $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):$(VERSION)

push: ## docker push the service images tagged 'latest' & 'BUILD_ID'
	docker push $(IMAGE_NAME):$(VERSION)

run: ## run docker image locally
	docker run -it $(IMAGE_NAME):$(VERSION)

readme:
	echo "\n## Required Environment Variables\n" >> README.md
	sed -n 's/echo "set \([A-Z].*\)."*/- \1/p' entrypoint.sh >> README.md
	echo "\n## Optional Environment Variables\n" >> README.md
	sed -n 's/echo "\([A-Z].*will default to.*\)./- \1/p' entrypoint.sh >> README.md