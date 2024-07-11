#!/bin/bash
echo "Running protoc toolchain"
UID_GROUP=$(id -u):$(id -g)
PROTOC_VERSION=$1
SCRIPTS_DIR=$2

# Run native CPU arch for much better performance
ARCH="amd64"
if [[ "$(uname -a)" == *"arm64"* || "$(uname -a)" == *"aarch64"* ]]; then
	ARCH="arm64"
fi

function cleanOldVersions() {
	OLD_VERSIONS=$(docker images --format '{{.Repository}}:{{.Tag}}' --filter=reference="protoc:*" | wc -l)
	if [ "$OLD_VERSIONS" != "0" ]; then
		docker rmi $(docker images --format '{{.Repository}}:{{.Tag}}' --filter=reference="protoc:*")
	fi
}

function ensureVolumes() {
	docker volume ls -f name=modcache -q | grep modcache >/dev/null
	if [ "$?" != "0" ]; then
		docker volume create modcache >/dev/null
	fi
	docker volume ls -f name=envcache -q | grep envcache >/dev/null
	if [ "$?" != "0" ]; then
		docker volume create envcache >/dev/null
	fi
}

function ensureCurrentImageIsPresent() {
	docker images --format '{{.Repository}}:{{.Tag}}' --filter=reference="protoc:*" | grep v$1 >/dev/null
	if [ "$?" != "0" ]; then
		PB_RELEASE="protoc-$PROTOC_VERSION-linux-x86_64.zip"
		if [ "$ARCH" == "arm64" ]; then
			PB_RELEASE="protoc-$PROTOC_VERSION-linux-aarch_64.zip"
		fi
		cleanOldVersions
		docker build \
			--platform=linux/$ARCH \
			-t protoc:v$1 \
			--build-arg PROTOC_VERSION=$1 \
			--build-arg ARCH=$ARCH \
			--build-arg PB_RELEASE=$PB_RELEASE \
			-f .core/docker/Dockerfile.protoc \
			.
	fi
}

if [ "$BUILDCACHE" == "true" ]; then

	ensureCurrentImageIsPresent $PROTOC_VERSION
	ensureVolumes

	docker run --rm \
		-v modcache:/go/pkg \
		-v envcache:/go/src \
		--mount type=bind,source="$PWD",target=/go/src/github.com/jakekeeys/"$(basename $(pwd))" \
		--platform=linux/$ARCH \
		-v ~/.ssh:/tmp/.ssh:ro \
		-v ~/.gitconfig:/root/.gitconfig:ro \
		--workdir=/go/src/github.com/jakekeeys/$(basename $(pwd)) \
		-e GOPRIVATE=github.com/jakekeeys \
		-e BUILDCACHE=true \
		-e SCRIPTS_DIR=$SCRIPTS_DIR \
		protoc:v$PROTOC_VERSION \
		bash -ce "$SCRIPTS_DIR/setup.sh $UID_GROUP $PROTOC_VERSION"
else
	docker run --rm \
		--mount type=bind,source="$PWD",target=/go/src/github.com/jakekeeys/"$(basename $(pwd))" \
		--platform=linux/$ARCH \
		-v ~/.ssh:/tmp/.ssh:ro \
		-v ~/.gitconfig:/root/.gitconfig:ro \
		--workdir=/go/src/github.com/jakekeeys/$(basename $(pwd)) \
		-e GOPRIVATE=github.com/jakekeeys \
		-e SCRIPTS_DIR=$SCRIPTS_DIR \
		golang:1.22 \
		bash -ce "$SCRIPTS_DIR/setup.sh $UID_GROUP $PROTOC_VERSION"
fi
EXIT_CODE=$?
echo "Done"
exit $EXIT_CODE
