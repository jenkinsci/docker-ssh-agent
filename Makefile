ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

IMAGE_NAME:=jenkins4eval/ssh-slave
IMAGE_ALPINE:=${IMAGE_NAME}:alpine
IMAGE_DEBIAN:=${IMAGE_NAME}:test

build: build-alpine build-debian

build-alpine:
	docker build -t ${IMAGE_ALPINE} --file Dockerfile-alpine .

build-debian:
	docker build -t ${IMAGE_DEBIAN} --file Dockerfile .

