CONTAINER_ENGINE ?= podman

IMAGE := $(file <IMAGE)
VERSION := $(file <VERSION)

ifndef IMAGE
$(error IMAGE file not present in Makefile directory)
endif

.PHONY: all image push

all:
	${CONTAINER_ENGINE} run -v .:/work "$(IMAGE):$(VERSION)"

image: EPOCH := $(shell date +'%s')
image:
	${CONTAINER_ENGINE} build --no-cache . -t "$(IMAGE):$(EPOCH)"
	echo $(EPOCH) > VERSION

push:
	${CONTAINER_ENGINE} push "$(IMAGE):$(shell cat VERSION)"
