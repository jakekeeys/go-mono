VERSION := 42af717238c6921bbae5d167362c9f9b843fc532

TEAM=jakekeeys
BRANCH?=main
DOCKER_ID?=jakekeeys
REGISTRY?=registry.keeys.io
IMAGE_NAME_PREFIX?=jakekeeys

KUSTOMIZE_VERSION?=5.1.0
MANIFESTS_REPO?=git@github.com:jakekeeys/kubernetes-manifests.git
MANIFESTS_OVERLAY_PATH?=overlays/dev/

BUILDENV?=
BUILDENV += CC=$$(which musl-gcc)
BUILDENV += CGO_ENABLED=1
BUILDENV += GOARCH=amd64
BUILDENV += GOPRIVATE=github.com/jakekeeys
TESTFLAGS?=-test.v -cover --race -count=1 -failfast -mod=readonly
TESTCOVERFLAGS?=-coverprofile=coverage.txt
BUILDFLAGS?=-ldflags='-w -s -linkmode external'

PB_VERSION=26.1
LINT_VERSION=v1.58.1
CLANG_FORMAT_VERSION=1:11.0-51+nmu5
SHFMT_VERSION=v3.6.0
GOIMPORTS_VERSION=v0.5.0
GOFUMPT_VERSION=v0.4.0

.PHONY: version
version:
	@echo "monorepo-tools version ${VERSION}"

.PHONY: update
update:
	@./.core/scripts/update-tools.sh

test:
	BRANCH=$(BRANCH) TESTFLAGS="$(TESTFLAGS)" $(BUILDENV) ./.core/scripts/tests.sh

test-all:
	$(BUILDENV) go test $(TESTFLAGS) ./...

.PHONY: test-cover
test-cover:
	BRANCH=$(BRANCH) TESTFLAGS="$(TESTFLAGS) $(TESTCOVERFLAGS)" $(BUILDENV) ./.core/scripts/tests-cover.sh

.PHONY: test-cover-all
test-cover-all:
	TESTFLAGS="$(TESTFLAGS) $(TESTCOVERFLAGS)" $(BUILDENV) ./.core/scripts/tests-cover-all.sh

.PHONY: proto-fmt
proto-fmt:
	@./.core/scripts/fmt.sh ${CLANG_FORMAT_VERSION}  ${SHFMT_VERSION} ${GOIMPORTS_VERSION} ${GOFUMPT_VERSION} true

.PHONY: fmt
fmt:
	@./.core/scripts/fmt.sh ${CLANG_FORMAT_VERSION}  ${SHFMT_VERSION} ${GOIMPORTS_VERSION} ${GOFUMPT_VERSION}

.PHONY: check-format
check-format:
	@./.core/scripts/check-format.sh ${PB_VERSION} ${CLANG_FORMAT_VERSION}  ${SHFMT_VERSION} ${GOIMPORTS_VERSION} ${GOFUMPT_VERSION}

.PHONY: install-hooks
install-hooks:
	@cp .core/hooks/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit

lint:
	@./.core/scripts/lint.sh ${LINT_VERSION}

.PHONY: install
install:
	$(BUILDENV) go mod download

.PHONY: install-tools
install-tools: install
	@cat tools.go | grep _ | awk -F'"' '{print $$2}' | xargs -tI % go install %

.PHONY: protos
protos: proto-fmt
	@./.core/scripts/protos.sh ${PB_VERSION} .core/scripts/protos

.PHONY: protos-custom
protos-custom: proto-fmt
	 @./.core/scripts/protos.sh ${PB_VERSION} $$scripts

.PHONY: clients
clients: generate
	@TEAM=$(TEAM) ./.core/scripts/clients.sh

.PHONY: generate
generate:
	@go generate ./...

clean:
	@rm -rf pkg/clients

check: fmt lint test-all

changed:
	.core/scripts/changed.sh

build-binary:
	@rm -rf bin && mkdir bin
	if [ -f  ./services/$$service/main.go ]; then $(BUILDENV) go build $(BUILDFLAGS) -o bin/$$service ./services/$$service/main.go; else $(BUILDENV) go build $(BUILDFLAGS) -o bin/$$service ./services/$$service/cmd/$$service; fi


build-all-binaries:
	@rm -rf bin && mkdir bin
	for service in $$(ls services); do \
		echo "compiling $$service" && \
		if [ -f  ./services/$$service/main.go ]; then $(BUILDENV) go build $(BUILDFLAGS) -o bin/$$service ./services/$$service/main.go; else $(BUILDENV) go build $(BUILDFLAGS) -o bin/$$service ./services/$$service/cmd/$$service; fi; \
	done

build-changed-binaries:
	@rm -rf bin && mkdir bin
	export BRANCH=${BRANCH} && for service in $$(.core/scripts/changed.sh); do \
		echo "compiling $$service" && \
		if [ -f  ./services/$$service/main.go ]; then $(BUILDENV) go build $(BUILDFLAGS) -o bin/$$service ./services/$$service/main.go; else $(BUILDENV) go build $(BUILDFLAGS) -o bin/$$service ./services/$$service/cmd/$$service; fi; \
	done

build-container: build-binary
	mkdir -p docker/context/$$service && \
	cp -r bin/$$service services/$$service/assets docker/context/$$service 2>/dev/null || : && \
	docker build --build-arg SERVICE=${service} -t ${REGISTRY}/${IMAGE_NAME_PREFIX}-$$service:latest -f $$(test -f services/$$service/Dockerfile && echo services/$$service/Dockerfile || echo .core/docker/Dockerfile.service) docker/context/$$service && \
	rm -rf docker/context

build-containers:
	for service in $$(ls bin); do \
		echo "building $$service" && \
		mkdir -p docker/context/$$service && \
		cp -r bin/$$service services/$$service/assets docker/context/$$service 2>/dev/null || : && \
		docker build --build-arg SERVICE=$$service -t ${REGISTRY}/${IMAGE_NAME_PREFIX}-$$service:latest -f $$(test -f services/$$service/Dockerfile && echo services/$$service/Dockerfile || echo .core/docker/Dockerfile.service) docker/context/$$service; \
	done
	rm -rf docker/context

push-containers:
	docker login -u $(DOCKER_ID) -p ${DOCKER_PASSWORD} ${REGISTRY}
	for service in $$(ls bin); do \
		version=$$(git rev-parse HEAD) && \
		if [ "${GITHUB_HEAD_REF}" != "" ]; then branch=${GITHUB_HEAD_REF}; else branch=${GITHUB_REF_NAME}; fi && \
		hash=$$(echo ${GITHUB_SHA} | head -c 8) && \
		branch="$$(echo $$branch | sed 's/[\/_]/-/g')" && \
		echo "pushing $$service:$$version" && \
		echo "pushing $$service:$$branch-$$hash" && \
		docker tag ${REGISTRY}/${IMAGE_NAME_PREFIX}-$$service:latest ${REGISTRY}/${IMAGE_NAME_PREFIX}-$$service:$$version && \
		docker tag ${REGISTRY}/${IMAGE_NAME_PREFIX}-$$service:latest ${REGISTRY}/${IMAGE_NAME_PREFIX}-$$service:$$branch-$$hash && \
		docker push ${REGISTRY}/${IMAGE_NAME_PREFIX}-$$service:$$version; \
		docker push ${REGISTRY}/${IMAGE_NAME_PREFIX}-$$service:$$branch-$$hash; \
	done

containers-all: build-all-binaries build-containers
containers: build-changed-binaries build-containers

# The following *-binaries-parallel recipes are used by CI tools to distribute Docker operations
# amongst N concurrent workflow jobs. This works by taking the ordinal index of a compiled binary
# and performing a modulo operation against the number of available runners. If the modulo outcome
# equals the runner index then the operation is performed by the runner.
#
# For example:
# 	If `ls bin | sort` produced `app-1 app-2 app-3 app-4`, then running
#	`make ci-build-all-binaries-parallel index=1 runners=2` would result
#	in `building app-2` and `building app-4`. This is because 1 (building
#	app-2 ordinal index) % 2 (number of runners) == 1 (runner index). The
#	same applies to app-4 (ordinal index 3).
ci-build-all-binaries-parallel:
	@rm -rf bin && mkdir bin
	i=0; \
	for service in $$(ls services | sort); do \
		mod=$$(($$i % $(runners))); \
		if [ $$mod = $(index) ]; then \
			echo "compiling $$service" && \
			if [ -f  ./services/$$service/main.go ]; then $(BUILDENV) go build $(BUILDFLAGS) -o bin/$$service ./services/$$service/main.go; else $(BUILDENV) go build $(BUILDFLAGS) -o bin/$$service ./services/$$service/cmd/$$service; fi; \
		fi; \
		i=$$(($$i+1)); \
	done

ci-build-changed-binaries-parallel:
	@rm -rf bin && mkdir bin
	i=0; \
	export BRANCH=${BRANCH} && for service in $$(.core/scripts/changed.sh | sort); do \
		mod=$$(($$i % $(runners))); \
		if [ $$mod = $(index) ]; then \
			echo "compiling $$service" && \
			if [ -f  ./services/$$service/main.go ]; then $(BUILDENV) go build $(BUILDFLAGS) -o bin/$$service ./services/$$service/main.go; else $(BUILDENV) go build $(BUILDFLAGS) -o bin/$$service ./services/$$service/cmd/$$service; fi; \
		fi; \
		i=$$(($$i+1)); \
	done

ci-generate-build-artifacts:
	mkdir -p artifacts
	version=$$(git rev-parse HEAD) && \
	for service in $$(ls -p bin | grep -v /); do \
		echo $$version > artifacts/$$service; \
	done

ci-deploy-containers:
	git clone $(MANIFESTS_REPO) manifests
	wget https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
    tar xzvf kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
    sudo mv kustomize /usr/local/bin/kustomize && \
    sudo chmod +x /usr/local/bin/kustomize && \
    test -f /usr/local/bin/kustomize
	bins=$$(ls artifacts) && \
	cd manifests/${MANIFESTS_OVERLAY_PATH} && \
	for service in $$bins; do \
		kustomize edit set image ${REGISTRY}/${IMAGE_NAME_PREFIX}-$$service=${REGISTRY}/${IMAGE_NAME_PREFIX}-$$service:${GITHUB_SHA}; \
	done
	cd manifests && git add ${MANIFESTS_OVERLAY_PATH}/kustomization.yaml && git commit -m "Deploying ${GITHUB_SHA}"
	cd manifests && git push -u origin ${BRANCH}
	rm -rf manifests

ci-list-images:
	if [ ! -d artifacts ]; then echo "No artifacts created"; exit 0; fi && \
	bins=$$(ls artifacts) && \
	if [ "${GITHUB_HEAD_REF}" != "" ]; then branch=${GITHUB_HEAD_REF}; else branch=${GITHUB_REF_NAME}; fi && \
	hash=$$(echo ${GITHUB_SHA} | head -c 8) && \
	for service in $$bins; do \
  		echo ${REGISTRY}/${IMAGE_NAME_PREFIX}-$$service:$$branch-$$hash; \
	done

ci-raise-manifest-pr-dev:
	@git clone $(MANIFESTS_REPO) manifests-dev
	@wget -q https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
	tar xzf kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
	sudo mv kustomize /usr/local/bin/kustomize && \
	sudo chmod +x /usr/local/bin/kustomize && \
	test -f /usr/local/bin/kustomize

	@export MANIFEST_PATH=${MANIFESTS_OVERLAY_PATH} && \
	export REGISTRY=${REGISTRY} && \
	export IMAGE_NAME_PREFIX=${IMAGE_NAME_PREFIX} && \
	export BRANCH=${BRANCH} && .core/scripts/raise_pr_dev.sh

ci-raise-manifest-pr-prod:
	@git clone $(MANIFESTS_REPO) manifests-prod
	@wget -q https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
	tar xzf kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
	sudo mv kustomize /usr/local/bin/kustomize && \
	sudo chmod +x /usr/local/bin/kustomize && \
	test -f /usr/local/bin/kustomize

	@export MANIFEST_PATH=${MANIFESTS_OVERLAY_PATH} && \
	export REGISTRY=${REGISTRY} && \
	export IMAGE_NAME_PREFIX=${IMAGE_NAME_PREFIX} && \
	.core/scripts/close_prs_prod.sh && .core/scripts/raise_pr_prod.sh
