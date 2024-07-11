#!/bin/bash

LINT_VERSION=$1

# Run native CPU arch for much better performance
ARCH="amd64"
if [[ "$(uname -a)" == *"arm64"* || "$(uname -a)" == *"aarch64"* ]]; then
	ARCH="arm64"
fi

function cleanOldVersions() {
	OLD_VERSIONS=$(docker images --format '{{.Repository}}:{{.Tag}}' --filter=reference="golangci-lint:*" | wc -l)
	if [ "$OLD_VERSIONS" != "0" ]; then
		docker rmi $(docker images --format '{{.Repository}}:{{.Tag}}' --filter=reference="golangci-lint:*")
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
	docker volume ls -f name=lintcache -q | grep lintcache >/dev/null
	if [ "$?" != "0" ]; then
		docker volume create lintcache >/dev/null
	fi
}

function ensureCurrentImageIsPresent() {
	docker images --format '{{.Repository}}:{{.Tag}}' --filter=reference="golangci-lint:*" | grep $1 >/dev/null
	if [ "$?" != "0" ]; then
		cleanOldVersions
		docker build \
			--platform=linux/$ARCH \
			-t golangci-lint:$1 \
			--build-arg LINT_VERSION=$1 \
			--build-arg ARCH=$ARCH \
			-f .core/docker/Dockerfile.lint \
			.
	fi
}

echo "Running lint toolchain"
if [ "$BUILDCACHE" == "true" ]; then

	ensureCurrentImageIsPresent $LINT_VERSION
	ensureVolumes

	docker run --rm \
		-v modcache:/go/pkg \
		-v envcache:/go/src \
		-v lintcache:/root/.cache \
		--mount type=bind,source="$PWD",target=/go/src/github.com/jakekeeys/"$(basename $(pwd))" \
		--platform=linux/$ARCH \
		-v ~/.ssh:/tmp/.ssh:ro \
		-v ~/.gitconfig:/tmp/.gitconfig:ro \
		-e BUILDCACHE=true \
		--workdir=/go/src/github.com/jakekeeys/$(basename $(pwd)) \
		-e GOPRIVATE=github.com/jakekeeys \
		golangci-lint:$1 \
		bash -ce ".core/scripts/formatting/lint.sh $LINT_VERSION"
else
	docker run --rm \
		--mount type=bind,source="$PWD",target=/go/src/github.com/jakekeeys/"$(basename $(pwd))" \
		--platform=linux/$ARCH \
		-v ~/.ssh:/tmp/.ssh:ro \
		-v ~/.gitconfig:/tmp/.gitconfig:ro \
		--workdir=/go/src/github.com/jakekeeys/$(basename $(pwd)) \
		-e GOPRIVATE=github.com/jakekeeys \
		golang:1.22 \
		bash -ce ".core/scripts/formatting/lint.sh $LINT_VERSION"
fi
EXIT_CODE=$?
echo "Done"
exit $EXIT_CODE
