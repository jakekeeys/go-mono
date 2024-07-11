#!/bin/sh

repo=$(git rev-parse --show-toplevel)

# Run native CPU arch for much better performance
ARCH="amd64"
if [[ "$(uname -a)" == *"arm64"* || "$(uname -a)" == *"aarch64"* ]]; then
	ARCH="arm64"
fi

mkdir -p $repo/pkg/clients/generated
for f in $(find . -name 'swagger.json'); do
	pkg=$(echo $f | cut -d "/" -f 3- | cut -d "/" -f -1 | sed s/-/_/g)
	path=$(realpath $f)

	docker run -it --rm \
		-v $repo/pkg/clients/generated:/local/out \
		-v $path:/local/swagger.json \
		--platform=linux/$ARCH \
		-u $(id -u ${USER}):$(id -g ${USER}) \
		openapitools/openapi-generator-cli generate -i /local/swagger.json -g go --git-user-id="jakekeeys" --git-repo-id="$TEAM/pkg/clients/generated" --additional-properties packageName=$pkg,generateInterfaces=true,isGoSubmodule=true,enumClassPrefix=true -o /local/out/$pkg

	rm -rf $repo/pkg/clients/generated/$pkg/.openapi-generator
	rm $repo/pkg/clients/generated/$pkg/git_push.sh
done
