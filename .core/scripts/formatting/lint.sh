#!/bin/bash

# Run native CPU arch for much better performance
ARCH="amd64"
if [[ "$(uname -a)" == *"arm64"* || "$(uname -a)" == *"aarch64"* ]]; then
	ARCH="arm64"
fi

cp -r /tmp/.ssh /root/.ssh # copying from tmp to the root .ssh. This will change also the permissions to root
cp /tmp/.gitconfig /root/.gitconfig
git config --global --add safe.directory '*'
echo "• resolving Dependencies"
go mod download
go install mvdan.cc/gofumpt@v0.4.0

if [ "$BUILDCACHE" != "true" ]; then
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin $1 # version
fi

echo "• linting"
CC=$(which musl-gcc) CGO_ENABLED=1 GOARCH=$ARCH $GOPATH/bin/golangci-lint run --timeout=30m ./...
