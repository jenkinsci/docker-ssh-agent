ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

IMAGE_NAME:=jenkins4eval/ssh-slave
IMAGE_ALPINE:=${IMAGE_NAME}:alpine
IMAGE_DEBIAN:=${IMAGE_NAME}:test
IMAGE_JDK11:=${IMAGE_NAME}:jdk11

build: build-alpine build-debian build-jdk11

build-alpine:
	cp -f setup-sshd 8/alpine/
	docker build -t ${IMAGE_ALPINE} 8/alpine

build-debian:
	cp -f setup-sshd 8/debian/
	docker build -t ${IMAGE_DEBIAN} 8/debian
	
build-jdk11:
	cp -f setup-sshd 11/debian/
	docker build -t ${IMAGE_JDK11} 11/debian

bats:
	# The lastest version is v1.1.0
	@if [ ! -d bats-core ]; then git clone https://github.com/bats-core/bats-core.git; fi
	@git -C bats-core reset --hard c706d1470dd1376687776bbe985ac22d09780327

.PHONY: test test-alpine test-jdk11 test-debian
test: bats test-alpine test-jdk11 test-debian

test-alpine:
	@FOLDER="8/alpine" bats-core/bin/bats tests/tests.bats

test-jdk11:
	@FOLDER="11/debian" bats-core/bin/bats tests/tests.bats

test-debian:
	@FOLDER="8/debian" bats-core/bin/bats tests/tests.bats
