IMAGE := ghcr.io/cilium/ci-kernels-builder
VERSION := $(file <VERSION)

.PHONY: builder push

builder: EPOCH := $(shell date +'%s')
builder:
	docker build --no-cache . -t "$(IMAGE):$(EPOCH)"
	sed 's|$(IMAGE):[0-9]\+|$(IMAGE):$(EPOCH)|' -i ../build/Dockerfile
	echo $(EPOCH) > VERSION

push:
	docker push "$(IMAGE):$(shell cat VERSION)"
