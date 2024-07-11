#!/bin/bash

PROTOC_VERSION=$1
CLANG_FORMAT_VERSION=$2
SHFMT_VERSION=$3
GOIMPORTS_VERSION=$4
GOFUMPT_VERSION=$5

if [ -z $CI ]; then
	make generate
	./.core/scripts/protos.sh $PROTOC_VERSION
	./.core/scripts/fmt.sh $CLANG_FORMAT_VERSION $SHFMT_VERSION $GOIMPORTS_VERSION $GOFUMPT_VERSION
else
	go install github.com/golang/mock/mockgen@v1.6.0
	make generate
	./.core/scripts/protos/setup.sh $(id -u):$(id -g) $PROTOC_VERSION
	./.core/scripts/formatting/fmt.sh $(id -u):$(id -g) $CLANG_FORMAT_VERSION $SHFMT_VERSION $GOIMPORTS_VERSION $GOFUMPT_VERSION
fi
git diff --exit-code --output=/dev/null
