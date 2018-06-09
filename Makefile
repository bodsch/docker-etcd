
include env_make

NS       = bodsch
VERSION ?= latest

REPO     = docker-etcd
NAME     = etcd
INSTANCE = default

BUILD_DATE     := $(shell date +%Y-%m-%d)
BUILD_VERSION  := $(shell date +%y%m)
BUILD_TYPE     ?= "stable"
ETCD_VERSION   ?= "v3.3.7"

.PHONY: build push shell run start stop rm release

default: build

params:
	@echo ""
	@echo " ETCD_VERSION : ${ETCD_VERSION}"
	@echo " BUILD_DATE   : $(BUILD_DATE)"
	@echo ""

build: params
	docker build \
		--rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg BUILD_TYPE=$(BUILD_TYPE) \
		--build-arg ETCD_VERSION=${ETCD_VERSION} \
		--tag $(NS)/$(REPO):$(ETCD_VERSION) .

history:
	docker history \
		$(NS)/$(REPO):$(ETCD_VERSION)

push:
	docker push \
		$(NS)/$(REPO):$(ETCD_VERSION)

shell:
	docker run \
		--rm \
		--name $(NAME)-$(INSTANCE) \
		--interactive \
		--tty \
		--entrypoint "" \
		$(PORTS) \
		$(VOLUMES) \
		$(ENV) \
		$(NS)/$(REPO):$(ETCD_VERSION) \
		/bin/sh

run:
	docker run \
		--rm \
		--name $(NAME)-$(INSTANCE) \
		$(PORTS) \
		$(VOLUMES) \
		$(ENV) \
		$(NS)/$(REPO):$(ETCD_VERSION)

exec:
	docker exec \
		--interactive \
		--tty \
		$(NAME)-$(INSTANCE) \
		/bin/sh

start:
	docker run \
		--detach \
		--name $(NAME)-$(INSTANCE) \
		$(PORTS) \
		$(VOLUMES) \
		$(ENV) \
		$(NS)/$(REPO):$(ETCD_VERSION)

stop:
	docker stop \
		$(NAME)-$(INSTANCE)

clean:
	docker rmi -f `docker images -q ${NS}/${REPO} | uniq`

#
# List all images
#
list:
	-docker images $(NS)/$(REPO)*

release: build
	make push -e VERSION=$(ETCD_VERSION)

publish:
	# amd64 / community / cpy3
	docker push $(NS)/$(REPO):$(ETCD_VERSION)
