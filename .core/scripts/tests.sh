#!/bin/bash

git fetch origin ${BRANCH}
failed="false"
for service in $(git diff origin/${BRANCH} --name-only --diff-filter=ACM services | awk -F "/" '{print $2}' | uniq); do
	${BUILDENV} go test ${TESTFLAGS} ./services/$service/... || failed="true"
done
if [ "$failed" = "true" ]; then
	exit 1
fi
