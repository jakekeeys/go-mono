#!/bin/bash

failed="false"

${BUILDENV} go test ${TESTFLAGS} ./... || failed="true"

if [ "$failed" = "true" ]; then
	exit 1
fi

go get github.com/axw/gocov/gocov
go get github.com/AlekSi/gocov-xml

go install github.com/axw/gocov/gocov
go install github.com/AlekSi/gocov-xml

gocov convert coverage.txt | gocov-xml >coverage.xml
