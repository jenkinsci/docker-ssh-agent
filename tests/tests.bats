#!/usr/bin/env bats

SUT_IMAGE=jenkins-ssh-slave
SUT_CONTAINER=bats-jenkins-ssh-slave

load test_helpers
load keys

clean_test_container

@test "build image" {
	cd "${BATS_TEST_DIRNAME}"/.. || false
	docker build -t "${SUT_IMAGE}" .
}

@test "checking image metadata" {
	local VOLUMES_MAP="$(docker inspect -f '{{.Config.Volumes}}' ${SUT_IMAGE})"
	echo "${VOLUMES_MAP}" | grep '/tmp'
	echo "${VOLUMES_MAP}" | grep '/home/jenkins'
	echo "${VOLUMES_MAP}" | grep '/run'
	echo "${VOLUMES_MAP}" | grep '/var/run'
}

@test "image has bash and java installed and in the PATH" {
	docker run -d --name "${SUT_CONTAINER}" -P "${SUT_IMAGE}" "${PUBLIC_SSH_KEY}"

	docker exec "${SUT_CONTAINER}" which bash
	docker exec "${SUT_CONTAINER}" bash --version
	docker exec "${SUT_CONTAINER}" which java
	docker exec "${SUT_CONTAINER}" java -version

	clean_test_container
}

@test "create slave container with pubkey as argument" {
	docker run -d --name "${SUT_CONTAINER}" -P "${SUT_IMAGE}" "${PUBLIC_SSH_KEY}"

    is_slave_container_running

	run_through_ssh echo f00

	[ "$status" = "0" ] && [ "$output" = "f00" ] \
		|| (\
			echo "status: $status"; \
			echo "output: $output"; \
			false \
		)

    clean_test_container
}

@test "create slave container with pubkey as environment variable" {
	docker run -e "JENKINS_SLAVE_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${SUT_CONTAINER}" -P "${SUT_IMAGE}"

    is_slave_container_running

	run_through_ssh echo f00

	[ "$status" = "0" ] && [ "$output" = "f00" ] \
		|| (\
			echo "status: $status"; \
			echo "output: $output"; \
			false \
		)

    clean_test_container
}
