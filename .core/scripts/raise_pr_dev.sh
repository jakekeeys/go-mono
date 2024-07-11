#!/bin/bash

changed="$(.core/scripts/changed.sh)"
changedCount=$(echo "$changed" | grep -v ^$ | wc -l)
if [ $changedCount -ne "0" ]; then
	cd manifests-dev/$MANIFEST_PATH
	hash=$(echo ${GITHUB_SHA} | head -c 8)

	if [ "${GITHUB_HEAD_REF}" != "" ]; then branch=${GITHUB_HEAD_REF}; else branch=${GITHUB_REF_NAME}; fi

	for service in $changed; do
		kustomize edit set image ${REGISTRY}/${IMAGE_NAME_PREFIX}-$service=${REGISTRY}/${IMAGE_NAME_PREFIX}-$service:$branch-$hash
	done

	git checkout -b ci-$branch-$hash-dev
	git add kustomization.yaml
	git commit --quiet -m "ci: Deploying ${GITHUB_SHA}"
	git push --quiet -u origin ci-$branch-$hash-dev

	gh pr create --title "[ci] Deploying $branch ($hash) to dev" --body "Deploys @${GITHUB_ACTOR}'s changes from $branch ($hash) to dev."
else
	echo "Hmm, nothing has changed :thinking:"
fi
