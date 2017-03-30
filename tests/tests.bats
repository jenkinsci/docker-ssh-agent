#!/usr/bin/env bats

SUT_IMAGE=jenkins-ssh-slave
SUT_CONTAINER=bats-jenkins-ssh-slave

load test_helpers
load keys

@test "build image" {
	cd "${BATS_TEST_DIRNAME}"/.. || false
	docker build -t "${SUT_IMAGE}" .
}

@test "checking image metadatas" {
	local VOLUMES_MAP="$(docker inspect -f '{{.Config.Volumes}}' ${SUT_IMAGE})"
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

# run a given command through ssh on the test container.
# Use the $status, $output and $lines variables to make assertions
function run_through_ssh {
	SSH_PORT=$(get_port 22)
	if [ "$SSH_PORT" = "" ]; then
		echo "failed to get SSH port"
		false
	else
		TMP_PRIV_KEY_FILE=$(mktemp "$BATS_TMPDIR"/bats_private_ssh_key_XXXXXXX)
		echo "$PRIVATE_SSH_KEY" > $TMP_PRIV_KEY_FILE \
		 	&& chmod 0600 $TMP_PRIV_KEY_FILE

		run ssh -i $TMP_PRIV_KEY_FILE \
			-o LogLevel=quiet \
			-o UserKnownHostsFile=/dev/null \
			-o StrictHostKeyChecking=no \
			-l jenkins \
			localhost \
			-p $SSH_PORT \
			"$@"

		rm -f $TMP_PRIV_KEY_FILE
	fi
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
