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

# CI combines the exact architecture images this workflow run pushed; see
# wodby/images arch-image-pins. Per-architecture tags are shared by every run,
# so an overlapping run may already have replaced one of them.
arch-image = $(if $(ARCH_IMAGE_PINS),$(or $(shell cat '$(ARCH_IMAGE_PINS)/$(subst :,_,$(subst /,_,$(1)))' 2>/dev/null),$(error No digest of $(1) was pushed by this workflow run)),$(1))

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
				$(call arch-image,$(REPO):$(TAG)-amd64) \
				$(call arch-image,$(REPO):$(TAG)-arm64)

shell:
	docker run --rm --name $(NAME) -i -t $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) /bin/bash

run:
	docker run --rm --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) $(CMD)

clean:
	-docker rm -f $(NAME)

# Print the image make builds and pushes; CI pushes exactly this reference.
.PHONY: image-ref
image-ref:
	@printf '%s\n' '$(REPO):$(TAG)'
