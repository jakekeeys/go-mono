# Go Monorepo

# Table of Contents

1. [Makefile](#makefile)
1. [Deploying](#deploying)
1. [Repository Layout](#repository-layout)
1. [Using this Repository](#using-this-repository)
    1. [Protocol Buffers](#protocol-buffers)
        1. [GRPC Gateways](#grpc-gateways)
        1. [REST Clients](#rest-clients)
1. [Contributing](#contributing)

## Makefile

A [Makefile](./Makefile) exists in the root directory of the monorepo to help perform various tasks. The Makefile inherits the generic .core Makefile and allows each individual monorepos to overwrite and extend the provided functionality. See .core/README.md for more information.

You can update the version of tools imported into this monorepo by issuing a `make update`. Using `make version` shows the current tooling version.

### Host to Docker DNS

Included in the docker-compose stack is a DNS server. This allows you to use DNS to resolve your containers. To use this, add the configured DNS IP address to your `/etc/resolv.conf` file on your host machine. For us this is `172.20.0.8`. Once this has been added you can target your containers using their Docker DNS name. Eg, visiting `http://mongo-ui:8081` in your browser will give you the mongo-ui container. This is handy when developing with inter-service dependencies, or when you want to quickly take a look at a service's Swagger UI.

## Deploying

To deploy to `<environment>-dev` you will need to create a manifest in the [kubernetes manifests](https://github.com/jakekeeys/kubernetes-manifests)
repository. Upon merging your go-mono pull-request GitHub Actions will automatically create an image tag patch using Kustomize and commit it to the master branch of kubernetes-manifests. Your change will then be picked up by ArgoCD and deployed. Deploying to production remains a manual task. For more information on deploying services to production see the documentation in the [kubernetes manifests](https://github.com/jakekeeys/kubernetes-manifests) repository.


## Repository Layout

* [cmd](cmd) - useful tools related to the monorepo or CI.
* [pkg](pkg) - importable go-mono Go packages.
* [protos](protos) - Protocol Buffer contracts.
* [services](services) - services organised by deployment unit.

As a general rule, this repository follows the [Golang standards project layout](https://github.com/golang-standards/project-layout).

## Using this Repository

### Protocol Buffers

All Protocol Buffer contracts are stored in the `protos/` directory. We use a common naming convention to identify Protocol Buffers that belong to a service; for example the `OrderService` can be found under `services/order-service` and its corresponding Protocol Buffers can be found under `protos/order-service.proto`. Using such a naming convention allows for easy identification of ownership.

When authoring a new Protocol Buffer ensure that you correctly set the package name and options. This is especially important
when authoring a service definition. Below is an example from the `OrderService`:

```protobuf
syntax = "proto3";
package order_service;

option go_package = "github.com/jakekeeys/go-mono/pkg/order_service";

//...
```

**Note:** the name of the package (both `package` and `go_package`) use underscores, not hyphens.

#### GRPC Gateways

If your Protocol Buffer declares a `service` it's likely that you'll want a GRPC gateway deployed - running `make protos` automatically 
generates the corresponding `.pb.gw.go` file for you in the `pkg` directory for the service, as well as Swagger 
definitions (v2) under `docs/swagger/`. Swagger files are automatically copied into Docker containers under `/app/swagger.json` in line with our standard swagger-ui implementation.

**Note:** In order for the Swagger definitions to be correctly copied into Docker containers you must ensure that the package name in the Protocol Buffer file follows our naming convention.

#### REST Clients

In addition to GRPC Gateways, this repositories tooling can also automatically generate a corresponding REST Go client implementation using the OpenAPI spec. Executing `make clients` automatically builds all Protocol Buffers and generate clients for each service under the `pkg/clients/generated` directory.
