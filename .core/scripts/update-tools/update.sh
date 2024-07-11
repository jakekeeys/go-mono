#!/bin/sh

apk add git
apk add openssh-client

cp -r /tmp/.ssh /root/.ssh # copying from tmp to the root .ssh. This will change also the permissions to root

cd ./go/src/github.com/jakekeeys/$1

rm -rf ./.core &&
	git clone git@github.com:jakekeeys/monorepo-tools.git .core &&
	cd .core && sed "0,/fix_yo_build/ s/fix_yo_build/$$(git rev-parse HEAD)/g" -i Makefile &&
	rm -rf .git

chown -R $2:$3 /go/src/github.com/jakekeeys/$1/.core # change permissions to host user
