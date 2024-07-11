#!/bin/bash

services=$(ls artifacts)

cd manifests-prod/$MANIFEST_PATH
hash=$(echo ${GITHUB_SHA} | head -c 8)

if [ "${GITHUB_HEAD_REF}" != "" ]; then branch=${GITHUB_HEAD_REF}; else branch=${GITHUB_REF_NAME}; fi

for service in $services; do
	kustomize edit set image ${REGISTRY}/${IMAGE_NAME_PREFIX}-$service=${REGISTRY}/${IMAGE_NAME_PREFIX}-$service:$branch-$hash
done

git checkout -b ci-$branch-$hash-prod
git add kustomization.yaml
git commit --quiet -m "ci: Deploying ${GITHUB_SHA}"
git push --quiet -u origin ci-$branch-$hash-prod

gh pr create --title "[ci] Deploying $branch ($hash) to prod" --body "Deploys @${GITHUB_ACTOR}'s changes from $branch ($hash) to prod."
