#!/bin/bash
echo "Running fmt toolchain"

UID_GROUP=$(id -u):$(id -g)
CLANG_FORMAT_VERSION=$1
SHFMT_VERSION=$2
GOIMPORTS_VERSION=$3
GOFUMPT_VERSION=$4
SKIP_GOFILES=$5

# Run native CPU arch for much better performance
ARCH="amd64"
if [[ "$(uname -a)" == *"arm64"* || "$(uname -a)" == *"aarch64"* ]]; then
	ARCH="arm64"
fi

function cleanOldVersions() {
	OLD_VERSIONS=$(docker images --format '{{.Repository}}:{{.Tag}}' --filter=reference="clang-format:*" | wc -l)
	if [ "$OLD_VERSIONS" != "0" ]; then
		docker rmi $(docker images --format '{{.Repository}}:{{.Tag}}' --filter=reference="clang-format:*")
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
	docker images --format '{{.Repository}}:{{.Tag}}' --filter=reference="clang-format:*" | grep $1 >/dev/null
	if [ "$?" != "0" ]; then
		cleanOldVersions
		docker build \
			--build-arg ARCH=$ARCH \
			--platform=linux/$ARCH \
			-t clang-format:$1 \
			-f .core/docker/Dockerfile.fmt \
			.
	fi
}

if [ "$BUILDCACHE" == "true" ]; then
	CLANG_VERSION_CLEAN=$(echo -n $CLANG_FORMAT_VERSION | sed -E 's/\+|\:/_/g')
	ensureCurrentImageIsPresent $CLANG_VERSION_CLEAN
	ensureVolumes

	docker run --rm \
		-v modcache:/go/pkg \
		-v envcache:/go/src \
		--mount type=bind,source="$PWD",target=/go/src/github.com/jakekeeys/"$(basename $(pwd))" \
		--platform=linux/$ARCH \
		--workdir=/go/src/github.com/jakekeeys/$(basename $(pwd)) \
		-e GOPRIVATE=github.com/jakekeeys \
		-e BUILDCACHE=true \
		clang-format:$CLANG_VERSION_CLEAN \
		bash -ce ".core/scripts/formatting/fmt.sh \
		$UID_GROUP $CLANG_FORMAT_VERSION $SHFMT_VERSION $GOIMPORTS_VERSION $GOFUMPT_VERSION $SKIP_GOFILES"
else
	docker run --rm \
		--mount type=bind,source="$PWD",target=/go/src/github.com/jakekeeys/"$(basename $(pwd))" \
		--platform=linux/$ARCH \
		--workdir=/go/src/github.com/jakekeeys/$(basename $(pwd)) \
		-e GOPRIVATE=github.com/jakekeeys \
		golang:1.22 \
		bash -ce ".core/scripts/formatting/fmt.sh \
		$UID_GROUP $CLANG_FORMAT_VERSION $SHFMT_VERSION $GOIMPORTS_VERSION $GOFUMPT_VERSION $SKIP_GOFILES"
fi
EXIT_CODE=$?
echo "Done"
exit $EXIT_CODE
