#!/bin/sh
UID_GROUP=$1

echo "• resolving dependencies"
if [ "$BUILDCACHE" != "true" ]; then
	apt-get update -y -q && apt-get install clang-format=$2 -y -q
fi

go install mvdan.cc/sh/v3/cmd/shfmt@$3
go install golang.org/x/tools/cmd/goimports@$4
go install mvdan.cc/gofumpt@$5

if [ "$6" != "true" ]; then
	echo "• executing goimports"
	grep -rnL -e '// Code generated' --exclude-dir={.git,generated} --include="*.go" --exclude="*.resolvers.go" | xargs -n 1 goimports -w

	echo "• executing gofmt"
	grep -rnL -e '// Code generated' --exclude-dir={.git,generated} --include="*.go" --exclude="*.resolvers.go" | xargs -n 1 gofumpt -w
fi
echo "• executing clang-format for proto files"
clang-format --style=google protos/*.proto -i

echo "• executing shfmt for bash files"
shfmt -l -w .

if [ -z $CI ]; then
	echo "• enforcing correct file ownership"

	# Correct file ownership but leave the .git dir alone.
	find . -type d -mindepth 1 -maxdepth 1 -and -not -name ".git" | xargs chown -R $UID_GROUP
fi
