-include env_make

MAUTIC_VER ?= 7.2.2
MAUTIC_VER_MINOR := $(basename $(MAUTIC_VER))
MAUTIC_VER_MAJOR := $(basename $(MAUTIC_VER_MINOR))

# Mautic runs on the Apache variant of wodby/php, at one PHP version.
PHP_VER ?= 8.4
BASE_IMAGE_REVISION ?=

TAG ?= $(MAUTIC_VER_MAJOR)

REPO = wodby/mautic
NAME = mautic-$(MAUTIC_VER_MAJOR)

IMAGETOOLS_TAG ?= $(TAG)

ifneq ($(ARCH),)
	override TAG := $(TAG)-$(ARCH)
endif

.PHONY: build test push shell run clean buildx-imagetools-create

# Resolve the same pinned base image for every local and CI build target.
include base-images.mk
BASE_IMAGE_TAG = $(PHP_VER)-apache$(if $(BASE_IMAGE_REVISION),-$(BASE_IMAGE_REVISION))

default: build

build:
	docker build --build-arg BASE_IMAGE="$(BASE_IMAGE)" --build-arg MAUTIC_VER=$(MAUTIC_VER) -t $(REPO):$(TAG) ./

test:
	cd ./tests && IMAGE=$(REPO):$(TAG) NAME=$(NAME) ./run.sh

push:
	docker push $(REPO):$(TAG)

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
				$(REPO):$(TAG)-amd64 \
				$(REPO):$(TAG)-arm64

shell:
	docker run --rm --name $(NAME) -i -t $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) /bin/bash

run:
	docker run --rm --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) $(CMD)

clean:
	-docker rm -f $(NAME)
