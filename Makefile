IMAGE := $(file <IMAGE)
VERSION := $(file <VERSION)

ifndef IMAGE
$(error IMAGE file not present in Makefile directory)
endif
.PHONY: all image push

all:
	./make.sh

image: EPOCH := $(shell date +'%s')
image:
	docker build --no-cache -f Dockerfile.builder . -t "$(IMAGE):$(EPOCH)"
	echo $(EPOCH) > VERSION

push:
	docker push "$(IMAGE):$(shell cat VERSION)"
