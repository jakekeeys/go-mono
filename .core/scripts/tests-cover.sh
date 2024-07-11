#!/bin/bash

git fetch origin ${BRANCH}

failed="false"
srvlist=""

for service in $(git diff origin/${BRANCH} --name-only --diff-filter=ACM services | awk -F "/" '{print $2}' | uniq); do
	srvlist="$srvlist ./services/$service/..."
done

if [ "$srvlist" = "" ]; then
	exit 0
fi

${BUILDENV} go test ${TESTFLAGS} $srvlist || failed="true"

if [ "$failed" = "true" ]; then
	exit 1
fi

go get github.com/axw/gocov/gocov
go get github.com/AlekSi/gocov-xml

go install github.com/axw/gocov/gocov
go install github.com/AlekSi/gocov-xml

gocov convert coverage.txt | gocov-xml >coverage.xml
