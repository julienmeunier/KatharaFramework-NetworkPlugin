#!/usr/bin/make -f

PLUGIN_NAME=kathara/katharanp
PLUGIN_CONTAINER=katharanp

.PHONY: buildx_create_environment test all_arm64 all_push_arm64 all_amd64 all_push_amd64

all_arm64: test clean_arm64 plugin_arm64
all_push_arm64: all_arm64 push_arm64

all_amd64: test clean_amd64 plugin_amd64
all_push_amd64: all_amd64 push_amd64

test:
	cat ./plugin-src/config.json | python3 -m json.tool

clean_%:
	docker plugin rm -f ${PLUGIN_NAME}:$* || true
	docker rm -f ${PLUGIN_CONTAINER}_rootfs || true
	docker buildx rm kat-np-builder || true
	rm -rf ./img-src/katharanp
	rm -rf ./go-src/katharanp
	rm -rf ./plugin-src/rootfs

gobuild_docker_%:
	docker run -ti --rm -v `pwd`/go-src/:/root/go-src golang:alpine3.14 /bin/sh -c "apk add -U make && cd /root/go-src && make gobuild_$*"

image_%: gobuild_docker_% buildx_create_environment
	mv ./go-src/katharanp ./img-src/
	docker buildx build --platform linux/$* --load -t ${PLUGIN_CONTAINER}:rootfs ./img-src/
	docker create --platform linux/$* --name ${PLUGIN_CONTAINER}_rootfs ${PLUGIN_CONTAINER}:rootfs
	mkdir -p ./plugin-src/rootfs
	docker export ${PLUGIN_CONTAINER}_rootfs | tar -x -C ./plugin-src/rootfs
	docker rm -vf ${PLUGIN_CONTAINER}_rootfs
	docker rmi ${PLUGIN_CONTAINER}:rootfs

plugin_%: image_%
	docker plugin create ${PLUGIN_NAME}:$* ./plugin-src/
	rm -rf ./plugin-src/rootfs

push_%: plugin_%
	docker plugin push ${PLUGIN_NAME}:$*

buildx_create_environment:
	docker buildx create --name kat-np-builder --use
	docker buildx inspect --bootstrap
