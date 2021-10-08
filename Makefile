DOCKER_REGISTRY = index.docker.io
IMAGE_NAME = kong-oidc
IMAGE_VERSION = latest
IMAGE_ORG = flaccid
IMAGE_TAG = $(DOCKER_REGISTRY)/$(IMAGE_ORG)/$(IMAGE_NAME):$(IMAGE_VERSION)
export DOCKER_BUILDKIT = 1
export DOCKER_BUILD_PROGRESS_TYPE = plain

WORKING_DIR := $(shell pwd)

.DEFAULT_GOAL := docker-build

.PHONY: build run

copy-local:: ## copy the plugin files from the container to a local folder
	@docker rm -f kong-oidc > /dev/null 2>& 1
	@docker create -ti --name kong-oidc $(DOCKER_REGISTRY)/$(IMAGE_ORG)/$(IMAGE_NAME):$(IMAGE_VERSION) echo
	@docker cp kong-oidc:/opt/kong/plugins/oidc ./kong-oidc
	@docker rm -f kong-oidc

k8s-create-configmap:: ## create configmap with files
	kubectl create configmap kong-plugin-oidc --from-file=kong-oidc

docker-release:: docker-build docker-push ## builds and pushes the docker image to the registry

docker-push:: ## pushes the docker image to the registry
		@docker push $(IMAGE_TAG)

docker-build:: ## builds the docker image locally
		@echo http_proxy=$(HTTP_PROXY) http_proxy=$(HTTPS_PROXY)
		@echo building $(IMAGE_TAG)
		docker build --pull \
			--progress $(DOCKER_BUILD_PROGRESS_TYPE) \
			--build-arg=http_proxy=$(HTTP_PROXY) \
			--build-arg=https_proxy=$(HTTPS_PROXY) \
			-t $(IMAGE_TAG) $(WORKING_DIR)

docker-run:: ## runs the docker image locally
		docker run \
			--rm \
			-it \
				$(DOCKER_REGISTRY)/$(IMAGE_ORG)/$(IMAGE_NAME):$(IMAGE_VERSION)

docker-run-shell:: ## runs the docker image locally but with shell
		@docker run \
			--rm \
			-it \
				$(DOCKER_REGISTRY)/$(IMAGE_ORG)/$(IMAGE_NAME):$(IMAGE_VERSION) /bin/sh

helm-install:: ## installs using helm from chart in repo
		@helm install \
			-f helm-values.prd.yaml \
			--namespace kong-oidc \
				kong-oidc-server charts/kong-oidc-server

helm-upgrade:: ## upgrades deployed helm release
		@helm upgrade \
			-f helm-values.prd.yaml \
			--namespace kong-oidc \
				kong-oidc-server charts/kong-oidc-server

helm-uninstall:: ## deletes and purges deployed helm release
		@helm uninstall \
			--namespace kong-oidc \
				kong-oidc-server

helm-render:: ## prints out the rendered chart
		@helm install \
			-f helm-values.prd.yaml \
			--namespace kong-oidc \
			--dry-run \
			--debug \
				kong-oidc-server charts/kong-oidc-server

helm-validate:: ## runs a lint on the helm chart
		@helm lint \
			-f helm-values.prd.yaml \
			--namespace kong-oidc \
				charts/kong-oidc-server

# a help target including self-documenting targets (see the awk statement)
define HELP_TEXT
Usage: make [TARGET]... [MAKEVAR1=SOMETHING]...

Available targets:
endef
export HELP_TEXT
help: ## this help target
	@cat .banner
	@echo
	@echo "$$HELP_TEXT"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / \
		{printf "\033[36m%-30s\033[0m  %s\n", $$1, $$2}' $(MAKEFILE_LIST)
