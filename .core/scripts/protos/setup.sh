#!/bin/bash
UID_GROUP=$1
PB_VERSION=$2

# Run native CPU arch for much better performance
ARCH="amd64"
if [[ "$(uname -a)" == *"arm64"* || "$(uname -a)" == *"aarch64"* ]]; then
	ARCH="arm64"
fi

PB_RELEASE="protoc-$PB_VERSION-linux-x86_64.zip"
if [ "$ARCH" == "arm64" ]; then
	PB_RELEASE="protoc-$PB_VERSION-linux-aarch_64.zip"
fi

if [ "$BUILDCACHE" != "true" ]; then
	# install proto
	echo "• Installing version $PB_VERSION of protoc"
	apt-get update
	apt-get install unzip
	curl -LO https://github.com/protocolbuffers/protobuf/releases/download/v$PB_VERSION/$PB_RELEASE
	unzip $PB_RELEASE -d $HOME/.local
	rm $PB_RELEASE
fi

cp -r /tmp/.ssh /root/.ssh # copying from tmp to the root .ssh. This will change also the permissions to root

echo "• Resolving dependencies"
if [ -z $CI ]; then
	go mod download
fi

for dep in $(ls /go/pkg/mod/github.com/jakekeeys/); do
	DESTINATION=/go/src/github.com/jakekeeys/${dep%@*}
	if [ "$DESTINATION" != $(pwd) ]; then
		cp -r /go/pkg/mod/github.com/jakekeeys/$dep $DESTINATION
	fi
done

mkdir -p /go/src/github.com/envoyproxy/
for dep in $(ls /go/pkg/mod/github.com/envoyproxy/); do
	cp -r /go/pkg/mod/github.com/envoyproxy/$dep /go/src/github.com/envoyproxy/${dep%@*}
done

GO111MODULE=off go get github.com/googleapis/googleapis
GO111MODULE=off go get github.com/grpc-ecosystem/grpc-gateway

go install \
	github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway \
	github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2 \
	google.golang.org/protobuf/cmd/protoc-gen-go \
	google.golang.org/grpc/cmd/protoc-gen-go-grpc \
	github.com/envoyproxy/protoc-gen-validate \
	github.com/jakekeeys/protoc-gen-protostrate

bash -ce "$SCRIPTS_DIR/generate_protos.sh $UID_GROUP # (user:group)"
