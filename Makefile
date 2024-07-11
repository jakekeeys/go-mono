include .core/Makefile

PHONY: integration-test-service
integration-test-service: clean-env start-environment
	go test ./services/$(service)/... -tags=integration -count=1 -v

PHONY: integration-test
integration-test: clean-env start-environment
	go test  ./... -tags=integration

PHONY: integration-test-coverage
integration-test-coverage: clean-env start-environment
	BRANCH=$(BRANCH) TESTFLAGS="$(TESTFLAGS) $(TESTCOVERFLAGS) -tags=integration" $(BUILDENV) ./.core/scripts/tests-cover.sh

PHONY: integration-test-coverage-all
integration-test-coverage-all: clean-env start-environment
	TESTFLAGS="$(TESTFLAGS) $(TESTCOVERFLAGS) -tags=integration" $(BUILDENV) ./.core/scripts/tests-cover-all.sh

start-environment:
	docker compose -f ./docker/docker-compose.yaml up -d

clean-env:
	docker compose -f ./docker/docker-compose.yaml down
