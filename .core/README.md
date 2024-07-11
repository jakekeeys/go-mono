# Monorepo Tools

A repository containing tooling for monorepos. This repository is designed to be a tooling "bolt-on" for monorepos, providing common funcionality shared across projects. Such as Go binary and Docker image compilation, linting, proto generaton, githooks and more.

All functions provided by this repository are exposed as Makefile recipes. They include:

| command | based on changes* | description |
| --- | --- | --- |
| `make version` || prints the monorepo tools version |
| `make update` || updates the embedded monorepo tools version |
| `make test` | ✓ |  executes unit tests for only changed packages | 
| `make test-all` || executes all unit tests | 
| `make sh-fmt` || executes [`sh-fmt`](https://github.com/mvdan/sh) for all shell files |
| `make proto-fmt` || formats Protocol Buffer (`protos/*.proto`) files (requires `clang-format` to be installed) |
| `make go-fmt` || executes [`gofumpt -s` and `gofumports -local`](https://github.com/mvdan/gofumpt) for non-generated Go code |
| `make fmt` || executes all formatters (`*-fmt` Makefile commands) |
| `make lint` || performs linting (see [.golangci.yaml](./.golangci.yaml)) |
| `make install` || downloads Go dependencies using `go mod download` |
| `make protos` || generates Go Protocol Buffer libraries and Swagger definitions |
| `make clients` || generates REST clients for all Protocol Buffers with `service` definitions |
| `make generate` || executes `go generate ./...` |
| `make clean` || cleans up build artifacts |
| `make check` || runs `make fmt lint test-all`. Useful for checking if CI will pass |
| `make build-binary service=my-service-name` || builds a single go binary.  |
| `make build-all-binaries` || builds all binaries |
| `make build-changed-binaries` | ✓ | builds changed Go binaries |
| `make build-container service=my-service-name` || builds a single Docker container |
| `make build-containers` || builds containers for binaries contained in `bin/` |
| `make push-containers` || pushes containers for binaries contained in `bin/` |
| `make containers-all` || compiles all Go binaries and builds all Docker containers |
| `make containers` | ✓ | compiles changed Go binaries and builds changed Docker containers |

Other recipes exist, but are not designed to be executed by the user. Instead, they should be run by a CI tool such as CircleCI or GitHub Actions. The documentation for such recipes can be found in the Makefile.

*"based on changes" means that the command operates only on files which have been changed between the branch `HEAD` and `origin/master`.

## Installation

To install the monorepo tools in your monorepo, clone the repository into `.core` (`git clone git@github.com:jakakeeys/monorepo-tools.git .core`). After you've done this once, you can perform updates using `make update`.

### Requirements

This repository makes assumptions about your monorepo structure. For full support, your monorepo must:

- house your copy of monorepo-tools in <monorepo-root>/.core
- house your service main.go at <monorepo-root>/services/<service-name>/cmd/<service-name>/main.go
- house your protocol buffers in <monorepo-root>/protos
- provide a `.golangci.yaml` configuration file at <monorepo-root>/.golangci.yaml
