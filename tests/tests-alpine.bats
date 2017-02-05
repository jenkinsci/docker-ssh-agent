#!/usr/bin/env bats

SUT_IMAGE=jenkins-ssh-slave:alpine
SUT_CONTAINER=bats-jenkins-ssh-slave-alpine

load test_helpers
load keys

@test "build image" {
	cd "$BATS_TEST_DIRNAME"/..
	docker build -t $SUT_IMAGE -f Dockerfile-alpine .
}

@test "checking image metadatas" {
	local VOLUMES_MAP="$(docker inspect -f '{{.Config.Volumes}}' jenkins-ssh-slave)"
	echo "${VOLUMES_MAP}" | grep '/tmp'
	echo "${VOLUMES_MAP}" | grep '/home/jenkins'
	echo "${VOLUMES_MAP}" | grep '/run'
	echo "${VOLUMES_MAP}" | grep '/var/run'
}

@test "clean test container" {
	docker kill "${SUT_CONTAINER}" &>/dev/null ||:
	docker rm -fv "${SUT_CONTAINER}" &>/dev/null ||:
}

@test "create slave container" {
	docker run -d --name "${SUT_CONTAINER}" -P $SUT_IMAGE "$PUBLIC_SSH_KEY"
}

@test "image has bash and java installed and in the PATH" {
	docker exec "${SUT_CONTAINER}" which bash
	docker exec "${SUT_CONTAINER}" bash --version
	docker exec "${SUT_CONTAINER}" which java
	docker exec "${SUT_CONTAINER}" java -version
}

@test "slave container is running" {
	sleep 1  # give time to sshd to eventually fail to initialize
	retry 3 1 assert "true" docker inspect -f {{.State.Running}} "${SUT_CONTAINER}"
}

@test "connection with ssh + private key" {
	run_through_ssh echo f00

	[ "$status" = "0" ] && [ "$output" = "f00" ] \
		|| (\
			echo "status: $status"; \
			echo "output: $output"; \
			false \
		)
}



@test "clean test container" {
	docker kill "${SUT_CONTAINER}" &>/dev/null ||:
	docker rm -fv "${SUT_CONTAINER}" &>/dev/null ||:
}

@test "create slave container with pubkey as environment variable" {
	docker run -e "JENKINS_SLAVE_SSH_PUBKEY=$PUBLIC_SSH_KEY" -d --name "${SUT_CONTAINER}" -P $SUT_IMAGE
}

@test "slave container is running" {
	sleep 1  # give time to sshd to eventually fail to initialize
	retry 3 1 assert "true" docker inspect -f {{.State.Running}} "${SUT_CONTAINER}"
}

@test "connection with ssh + private key" {
	run_through_ssh echo f00

	[ "$status" = "0" ] && [ "$output" = "f00" ] \
		|| (\
			echo "status: $status"; \
			echo "output: $output"; \
			false \
		)
}

@test "clean test container" {
	docker kill "${SUT_CONTAINER}" &>/dev/null ||:
	docker rm -fv "${SUT_CONTAINER}" &>/dev/null ||:
}
