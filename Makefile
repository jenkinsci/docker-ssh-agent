ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

## For Docker <=20.04
export DOCKER_BUILDKIT=1
## For Docker <=20.04
export DOCKER_CLI_EXPERIMENTAL=enabled
## Required to have docker build output always printed on stdout
export BUILDKIT_PROGRESS=plain

current_os := $(shell uname -s)
current_arch := $(shell uname -m)

export OS ?= $(shell \
	case "$(current_os)" in \
		(Linux) echo linux ;; \
		(Darwin) echo linux ;; \
		(MINGW*|MSYS*|CYGWIN*) echo windows ;; \
		(*) echo unknown ;; \
	esac)

export ARCH ?= $(shell \
	case $(current_arch) in \
		(x86_64) echo "amd64" ;; \
		(aarch64|arm64) echo "arm64" ;; \
		(armv7*) echo "arm/v7";; \
		(s390*|riscv*|ppc64le) echo $(current_arch);; \
		(*) echo "UNKNOWN-CPU";; \
	esac)

IMAGE_NAME:=jenkins4eval/ssh-agent

# Set to the path of a specific test suite to restrict execution only to this
# default is "all test suites in the "tests/" directory
TEST_SUITES ?= $(CURDIR)/tests

##### Macros
## Check the presence of a CLI in the current PATH
check_cli = type "$(1)" >/dev/null 2>&1 || { echo "Error: command '$(1)' required but not found. Exiting." ; exit 1 ; }
## Check if a given image or group exists in the current manifest docker-bake.hcl
check_image = $(MAKE) --silent list listgroup-linux | grep -w '$(1)' >/dev/null 2>&1 || { echo "Error: the image or group '$(1)' does not exist in manifest for the current platform '$(OS)/$(ARCH)'. Please check the output of '$(MAKE) list' or '$(MAKE) listgroup-linux'. Exiting." ; exit 1 ; }
# check_image = make --silent list | grep -w '$(1)' >/dev/null 2>&1 || { echo "Error: the image '$(1)' does not exist in manifest for the platform 'linux/$(ARCH)'. Please check the output of 'make list'. Exiting." ; exit 1 ; }
## Base "docker buildx base" command to be reused everywhere
bake_base_cli := docker buildx bake --file docker-bake.hcl
## Command to be used on build (only)
bake_cli := $(bake_base_cli) --load
## Default bake target
bake_default_target := linux

.PHONY: build
.PHONY: test test-alpine test-debian

check-reqs:
## Build requirements
	@$(call check_cli,bash)
	@$(call check_cli,git)
	@$(call check_cli,docker)
	@docker info | grep 'buildx:' >/dev/null 2>&1 || { echo "Error: Docker BuildX plugin required but not found. Exiting." ; exit 1 ; }
## Test requirements
	@$(call check_cli,curl)
	@$(call check_cli,jq)

## This function is specific to Jenkins infrastructure and isn't required in other contexts
docker-init: check-reqs
ifeq ($(CI),true)
ifeq ($(wildcard /etc/buildkitd.toml),)
	echo 'WARNING: /etc/buildkitd.toml not found, using default configuration.'
	docker buildx create --use --bootstrap --driver docker-container
else
	docker buildx create --use --bootstrap --driver docker-container --config /etc/buildkitd.toml
endif
else
	docker buildx create --use --bootstrap --driver docker-container
endif
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
	docker info
	docker buildx inspect --bootstrap

# Build all targets with the current OS and architecture
build: check-reqs
	@$(bake_cli) $(shell make --silent list) --set '*.platform=linux/$(ARCH)'

# Build a specific target with the current OS and architecture
build-%: check-reqs target show-%
	@$(call check_image,$*)
	@echo "== building $*"
	@$(bake_cli) --metadata-file=target/build-result-metadata_$*.json --set '*.platform=$(OS)/$(ARCH)' '$*'

# Build default bake group corresponding to the current OS but independently of the architecture
multiarchbuild: check-reqs show-$(OS)
	@$(bake_base_cli) $(OS)

# Build a specific bake group or target independently of the architecture or the OS
multiarchbuild-%: check-reqs show-%
	@$(bake_base_cli) $*

# Show all default targets
show:
	@$(MAKE) --silent show-$(bake_default_target)

# Show a specific target
show-%:
	@$(bake_base_cli) --progress=quiet --print $* | jq

# Show all targets depending on the architecture
showarch-%:
	@$(MAKE) --silent show | jq --arg arch "$(OS)/$*" '.target |= with_entries(select(.value.platforms | index($$arch)))'

# List tags of all default targets
tags:
	@$(MAKE) --silent tags-$(bake_default_target)

# List tags of a specific target
tags-%:
	@$(MAKE) --silent show-$* | jq -r '.target | to_entries[] | .key as $$name | .value.tags[] | "\(.) (\($$name))"' | LC_ALL=C sort -u

# Return the list of targets depending on the current OS and architecture
list: check-reqs
	@$(MAKE) --silent listarch-$(ARCH)

# Return the list of targets of a specific "target" (can be a docker bake group)
list-%: check-reqs
	@$(MAKE) --silent show-$* | jq -r '.target | keys[]'

# Return the list of targets depending on the current OS and architecture
listarch-%: check-reqs
	@$(MAKE) --silent showarch-$* | jq -r '.target | keys[]'

# Return the list of targets of a specific bake group
listgroup-%: check-reqs
	@$(MAKE) --silent show-$* | jq -r '.group | keys[]' | grep -v -e $* -e default

# Ensure bats exists in the current folder
bats:
	git clone --branch v1.14.0 https://github.com/bats-core/bats-core bats

# Ensure all bats submodules are up to date
prepare-test: bats check-reqs
	git submodule update --init --recursive
	mkdir -p target

# Publish all linux targets
publish:
	@$(bake_base_cli) linux --push

## Define bats options based on environment
# common flags for all tests
bats_flags := $(TEST_SUITES)
# if DISABLE_PARALLEL_TESTS true, then disable parallel execution
ifneq (true,$(DISABLE_PARALLEL_TESTS))
# If the GNU 'parallel' command line is absent, then disable parallel execution
parallel_cli := $(shell command -v parallel 2>/dev/null)
ifneq (,$(parallel_cli))
# If parallel execution is enabled, we should use all vCPUs available for the Docker Engine minus one (to avoid throttling system while using parallel tests)
test-%: PARALLEL_JOBS ?= $(shell echo $$(( $(shell docker run --rm alpine grep -c processor /proc/cpuinfo) - 1)))
test-%: bats_flags += --jobs $(PARALLEL_JOBS)
endif
endif
test-%: prepare-test
# Check that the image exists in the manifest
	@$(call check_image,$*)
# Ensure that the image is built
	@make --silent build-$*
ifeq ($(CI),true)
# Execute the test harness and write result to a TAP file
	bash -o pipefail -c '\
		IMAGE=$* bats/bin/bats $(bats_flags) \
			--formatter junit \
			--gather-test-outputs-in target/bats-outputs-$* \
			| tee target/junit-results-$*.xml; \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			echo "Bats test failure(s), collected outputs:"; \
			for file in target/bats-outputs-$*/*; do \
				if [ -f "$$file" ]; then \
					echo "===== $$file ====="; \
					cat "$$file"; \
				fi; \
			done; \
		fi; \
		exit $$status'
else
# Execute the test harness
	IMAGE=$* bats/bin/bats $(bats_flags)
endif

test: prepare-test
	@make --silent list | while read image; do make --silent "test-$${image}"; done
