.PHONY: build test unittest lint clean prepare update docker

GO=CGO_ENABLED=0 GO111MODULE=on go
GOCGO=CGO_ENABLED=1 GO111MODULE=on go

# see https://shibumi.dev/posts/hardening-executables
CGO_CPPFLAGS="-D_FORTIFY_SOURCE=2"
CGO_CFLAGS="-O2 -pipe -fno-plt"
CGO_CXXFLAGS="-O2 -pipe -fno-plt"
CGO_LDFLAGS="-Wl,-O1,–sort-common,–as-needed,-z,relro,-z,now"

MICROSERVICES=cmd/device-snmp

.PHONY: $(MICROSERVICES)

ARCH=$(shell uname -m)

DOCKERS=docker_device_snmp_go
.PHONY: $(DOCKERS)

# This pulls the version of the SDK from the go.mod file. It works by looking for the line
# with the SDK and printing just the version number that comes after it.
SDKVERSION=$(shell sed -En 's|.*github.com/edgexfoundry/device-sdk-go/v2 (v[\.0-9a-zA-Z-]+).*|\1|p' go.mod)

# this pulls the version from local VERSION file that is created by the Jenkins Pipeline.
VERSION=$(shell cat ./VERSION 2>/dev/null || echo 0.0.0)

GIT_SHA=$(shell git rev-parse HEAD)

CGOFLAGS=-ldflags "-linkmode=external \
				   -X github.com/edgexfoundry/device-sdk-go/v2/internal/common.SDKVersion=$(SDKVERSION) \
                   -X github.com/edgexfoundry/device-snmp-go.Version=$(VERSION)" \
                   -trimpath -mod=readonly -buildmode=pie

build: $(MICROSERVICES)

tidy:
	go mod tidy

cmd/device-snmp:
	$(GOCGO) build $(CGOFLAGS) -o $@ ./cmd

unittest:
	$(GOCGO) test ./... -coverprofile=coverage.out

lint:
	@which golangci-lint >/dev/null || echo "WARNING: go linter not installed. To install, run\n  curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b \$$(go env GOPATH)/bin v1.42.1"
	@if [ "z${ARCH}" = "zx86_64" ] && which golangci-lint >/dev/null ; then golangci-lint run --config .golangci.yml ; else echo "WARNING: Linting skipped (not on x86_64 or linter not installed)"; fi

test: unittest lint
	$(GOCGO) vet ./...
	gofmt -l $$(find . -type f -name '*.go'| grep -v "/vendor/")
	[ "`gofmt -l $$(find . -type f -name '*.go'| grep -v "/vendor/")`" = "" ]
	./bin/test-attribution-txt.sh

clean:
	rm -f $(MICROSERVICES)

update:
	$(GO) mod download

run:
	cd bin && ./edgex-launch.sh

docker: $(DOCKERS)

docker_device_snmp_go:
	docker build \
		--label "git_sha=$(GIT_SHA)" \
		-t edgexfoundry/device-snmp:$(GIT_SHA) \
		-t edgexfoundry/device-snmp:$(VERSION)-dev \
		.

vendor:
	$(GO) mod vendor
