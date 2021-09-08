#!/usr/bin/env bats

load test_helpers
load 'test_helper/bats-support/load' # this is required by bats-assert!
load 'test_helper/bats-assert/load'
load keys

IMAGE=${IMAGE:-debian_jdk11}
SUT_IMAGE=$(get_sut_image)

ARCH=${ARCH:-x86_64}
AGENT_CONTAINER=bats-jenkins-ssh-agent

clean_test_container

function teardown () {
  clean_test_container
}

@test "[${SUT_IMAGE}] checking image metadata" {
  local VOLUMES_MAP="$(docker inspect -f '{{.Config.Volumes}}' "${SUT_IMAGE}")"

  echo "${VOLUMES_MAP}" | grep '/tmp'
  echo "${VOLUMES_MAP}" | grep '/home/jenkins'
  echo "${VOLUMES_MAP}" | grep '/run'
  echo "${VOLUMES_MAP}" | grep '/var/run'
}

@test "[${SUT_IMAGE}] image has bash and java installed and in the PATH" {
  docker run -d --name "${AGENT_CONTAINER}" -P "${SUT_IMAGE}" "${PUBLIC_SSH_KEY}"

  run docker exec "${AGENT_CONTAINER}" which bash
  assert_success
  run docker exec "${AGENT_CONTAINER}" bash --version
  assert_success
  run docker exec "${AGENT_CONTAINER}" which java
  assert_success

  run docker exec "${AGENT_CONTAINER}" sh -c "java -version"
  assert_success
}

@test "[${SUT_IMAGE}] create agent container with pubkey as argument" {
  docker run -d --name "${AGENT_CONTAINER}" -P "${SUT_IMAGE}" "${PUBLIC_SSH_KEY}"

  is_agent_container_running

  run_through_ssh echo f00
  assert_success
  assert_equal "${output}" "f00"
}

@test "[${SUT_IMAGE}] create agent container with pubkey as environment variable (legacy environment variable)" {
  docker run -e "JENKINS_SLAVE_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${AGENT_CONTAINER}" -P "${SUT_IMAGE}"

  is_agent_container_running

  run_through_ssh echo f00
  assert_success
  assert_equal "${output}" "f00"
}

@test "[${SUT_IMAGE}] create agent container with pubkey as environment variable (JENKINS_AGENT_SSH_PUBKEY)" {
  docker run -e "JENKINS_AGENT_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${AGENT_CONTAINER}" -P "${SUT_IMAGE}"

  is_agent_container_running

  run_through_ssh echo f00
  assert_success
  assert_equal "${output}" "f00"
}

@test "[${SUT_IMAGE}] Run Java in a SSH connection" {
  docker run -e "JENKINS_AGENT_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${AGENT_CONTAINER}" -P "${SUT_IMAGE}"

  is_agent_container_running

  if [[ "${SUT_IMAGE}" == *"alpine"*  ]]
  then
    run_through_ssh "/bin/bash --login -c 'java -version'"
  else
    run_through_ssh java -version
  fi
  assert_success
  assert_output --regexp '^openjdk version \"[[:digit:]]+\.'
}

DOCKER_PLUGIN_DEFAULT_ARG="/usr/sbin/sshd -D -p 22"
@test "[${SUT_IMAGE}] create agent container like docker-plugin with '${DOCKER_PLUGIN_DEFAULT_ARG}' (unquoted) as argument" {
  [ -n "$DOCKER_PLUGIN_DEFAULT_ARG" ]

  docker run -e "JENKINS_AGENT_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${AGENT_CONTAINER}" -P "${SUT_IMAGE}" ${DOCKER_PLUGIN_DEFAULT_ARG}

  is_agent_container_running

  run_through_ssh echo f00
  assert_success
  assert_equal "${output}" "f00"
}

@test "[${SUT_IMAGE}] create agent container with '${DOCKER_PLUGIN_DEFAULT_ARG}' (quoted) as argument" {
  [ -n "$DOCKER_PLUGIN_DEFAULT_ARG" ]

  docker run -e "JENKINS_AGENT_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${AGENT_CONTAINER}" -P "${SUT_IMAGE}" "${DOCKER_PLUGIN_DEFAULT_ARG}"

  is_agent_container_running

  run_through_ssh echo f00
  assert_success
  assert_equal "${output}" "f00"
}

@test "[${SUT_IMAGE}] use build args correctly" {
  cd "${BATS_TEST_DIRNAME}"/.. || false

	local TEST_USER=test-user
	local TEST_GROUP=test-group
	local TEST_UID=2000
	local TEST_GID=3000
	local TEST_JAH=/home/something

	local sut_image="${SUT_IMAGE}-tests-${BATS_TEST_NUMBER}"

  # false positive detecting platform
  # shellcheck disable=SC2140
  docker buildx bake \
    --set "${IMAGE}".args.user="${TEST_USER}" \
    --set "${IMAGE}".args.group="${TEST_GROUP}" \
    --set "${IMAGE}".args.uid="${TEST_UID}" \
    --set "${IMAGE}".args.gid="${TEST_GID}" \
    --set "${IMAGE}".args.JENKINS_AGENT_HOME="${TEST_JAH}" \
    --set "${IMAGE}".platform="linux/${ARCH}" \
    --set "${IMAGE}".tags="${sut_image}" \
      --load `# Image should be loaded on the Docker engine`\
      "${IMAGE}"

  docker run -d --name "${AGENT_CONTAINER}" -P "${sut_image}" "${PUBLIC_SSH_KEY}"

  run docker exec "${AGENT_CONTAINER}" sh -c "id -u -n ${TEST_USER}"
  assert_line --index 0 "${TEST_USER}"
  run docker exec "${AGENT_CONTAINER}" sh -c "id -g -n ${TEST_USER}"
  assert_line --index 0 "${TEST_GROUP}"
  run docker exec "${AGENT_CONTAINER}" sh -c "id -u ${TEST_USER}"
  assert_line --index 0 "${TEST_UID}"
  run docker exec "${AGENT_CONTAINER}" sh -c "id -g ${TEST_USER}"
  assert_line --index 0 "${TEST_GID}"
  run docker exec "${AGENT_CONTAINER}" sh -c 'stat -c "%U:%G" "${JENKINS_AGENT_HOME}"'
  assert_line --index 0 "${TEST_USER}:${TEST_GROUP}"
}
