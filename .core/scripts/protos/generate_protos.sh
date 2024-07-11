#!/bin/bash
echo "• Running protoc"
UID_GROUP=$1

repo=$(pwd)
export PATH="$PATH:$HOME/.local/bin" # adding protoc to PATH

protoPath="$repo/protos"
servicesPath="$repo/services"
goImports="-I=$GOPATH/src"

for f in $protoPath/*.proto; do
	SERVICE=$(basename $f)
	SERVICE=${SERVICE//.proto/}
	SERVICE=${SERVICE//_/-}
	if [[ ! -z $(grep -e "service .* {" $f) ]] && [[ -f "$servicesPath/$SERVICE/cmd/$SERVICE/main.go" ]]; then
		protoc $goImports -I$protoPath -I$GOPATH/src/github.com/googleapis/googleapis:$GOPATH/src/github.com/grpc-ecosystem/grpc-gateway/ \
			-I $GOPATH/src/github.com/envoyproxy/protoc-gen-validate \
			--go_out=$GOPATH/src \
			--go-grpc_out=$GOPATH/src \
			--protostrate_out=$GOPATH/src \
			--grpc-gateway_out=logtostderr=true,request_context=true:$GOPATH/src \
			--validate_out="lang=go:$GOPATH/src" \
			--openapiv2_out=logtostderr=true:$GOPATH/src $f
	elif [[ ! -z $(grep -e "service .* {" $f) ]] && [[ -f "$servicesPath/$SERVICE/main.go" ]]; then
		protoc $goImports -I$protoPath -I$GOPATH/src/github.com/googleapis/googleapis:$GOPATH/src/github.com/grpc-ecosystem/grpc-gateway/ \
			-I $GOPATH/src/github.com/envoyproxy/protoc-gen-validate \
			--go_out=$GOPATH/src \
			--go-grpc_out=$GOPATH/src \
			--protostrate_out=$GOPATH/src \
			--grpc-gateway_out=logtostderr=true,request_context=true:$GOPATH/src \
			--validate_out="lang=go:$GOPATH/src" \
			--openapiv2_out=logtostderr=true:$GOPATH/src $f
	else
		protoc $goImports -I$protoPath -I$GOPATH/src/github.com/googleapis/googleapis:$GOPATH/src/github.com/grpc-ecosystem/grpc-gateway/ \
			-I $GOPATH/src/github.com/envoyproxy/protoc-gen-validate \
			--go_out=$GOPATH/src \
			--protostrate_out=$GOPATH/src \
			--validate_out="lang=go:$GOPATH/src" \
			--go-grpc_out=$GOPATH/src $f
	fi
done

for s in $protoPath/*.swagger.json; do
	svc=$(basename $s .swagger.json)
	svc=${svc//_/-}
	mkdir -p services/$svc/internal/swagger
	mv $s services/$svc/internal/swagger/swagger.json
	cat <<EOF >services/$svc/internal/swagger/embed.go
package swagger

import "embed"

// Static is an embedded file server containing static HTTP assets.
//
//go:embed *
var Static embed.FS
EOF
done

if [ -z $CI ]; then
	echo "• enforcing correct file ownership"

	# Correct file ownership but leave the .git dir alone.
	find . -type d -mindepth 1 -maxdepth 1 -and -not -name ".git" | xargs chown -R $UID_GROUP
fi
