#!/usr/bin/env bats

load test_helpers
load 'test_helper/bats-support/load' # this is required by bats-assert!
load 'test_helper/bats-assert/load'
load keys

IMAGE=${IMAGE:-debian_jdk11}
SUT_IMAGE=$(get_sut_image)

ARCH=${ARCH:-x86_64}
AGENT_CONTAINER=bats-jenkins-ssh-agent

@test "[${SUT_IMAGE}] checking image metadata" {
  local VOLUMES_MAP
  VOLUMES_MAP="$(docker inspect -f '{{.Config.Volumes}}' "${SUT_IMAGE}")"

  echo "${VOLUMES_MAP}" | grep '/tmp'
  echo "${VOLUMES_MAP}" | grep '/home/jenkins'
  echo "${VOLUMES_MAP}" | grep '/run'
  echo "${VOLUMES_MAP}" | grep '/var/run'
}

@test "[${SUT_IMAGE}] image has bash and java installed and in the PATH" {
  local test_container_name=${AGENT_CONTAINER}-bash-java
  clean_test_container "${test_container_name}"
  docker run -d --name "${test_container_name}" -P "${SUT_IMAGE}" "${PUBLIC_SSH_KEY}"

  run docker exec "${test_container_name}" which bash
  assert_success
  run docker exec "${test_container_name}" bash --version
  assert_success
  run docker exec "${test_container_name}" which java
  assert_success

  run docker exec "${test_container_name}" sh -c "java -version"
  assert_success

  clean_test_container "${test_container_name}"
}

@test "[${SUT_IMAGE}] create agent container with pubkey as argument" {
  local test_container_name=${AGENT_CONTAINER}-pubkey-arg
  clean_test_container "${test_container_name}"
  docker run -d --name "${test_container_name}" -P "${SUT_IMAGE}" "${PUBLIC_SSH_KEY}"

  is_agent_container_running "${test_container_name}"

  run_through_ssh "${test_container_name}" echo f00
  assert_success
  assert_equal "${output}" "f00"

  clean_test_container "${test_container_name}"
}

@test "[${SUT_IMAGE}] create agent container with pubkey as environment variable (legacy environment variable)" {
  local test_container_name=${AGENT_CONTAINER}-pubkey-legacy-env
  clean_test_container "${test_container_name}"
  docker run -e "JENKINS_SLAVE_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${test_container_name}" -P "${SUT_IMAGE}"

  is_agent_container_running "${test_container_name}"

  run_through_ssh "${test_container_name}" echo f00
  assert_success
  assert_equal "${output}" "f00"

  clean_test_container "${test_container_name}"
}

@test "[${SUT_IMAGE}] create agent container with pubkey as environment variable (JENKINS_AGENT_SSH_PUBKEY)" {
  local test_container_name=${AGENT_CONTAINER}-pubkey-env
  clean_test_container "${test_container_name}"
  docker run -e "JENKINS_AGENT_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${test_container_name}" -P "${SUT_IMAGE}"

  is_agent_container_running "${test_container_name}"

  run_through_ssh "${test_container_name}" echo f00
  assert_success
  assert_equal "${output}" "f00"

  clean_test_container "${test_container_name}"
}

@test "[${SUT_IMAGE}] Run Java in a SSH connection" {
  local test_container_name=${AGENT_CONTAINER}-java-in-ssh
  clean_test_container "${test_container_name}"
  docker run -e "JENKINS_AGENT_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${test_container_name}" -P "${SUT_IMAGE}"

  is_agent_container_running "${test_container_name}"

  if [[ "${SUT_IMAGE}" == *"alpine"*  ]]
  then
    run_through_ssh "${test_container_name}" "/bin/bash --login -c 'java -version'"
  else
    run_through_ssh "${test_container_name}" java -version
  fi
  assert_success
  assert_output --regexp '^openjdk version \"[[:digit:]]+\.'

  clean_test_container "${test_container_name}"
}

DOCKER_PLUGIN_DEFAULT_ARG="/usr/sbin/sshd -D -p 22"
@test "[${SUT_IMAGE}] create agent container like docker-plugin with '${DOCKER_PLUGIN_DEFAULT_ARG}' (unquoted) as argument" {
  [ -n "$DOCKER_PLUGIN_DEFAULT_ARG" ]

  local test_container_name=${AGENT_CONTAINER}-docker-plugin
  clean_test_container "${test_container_name}"
  docker run -e "JENKINS_AGENT_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${test_container_name}" -P "${SUT_IMAGE}" ${DOCKER_PLUGIN_DEFAULT_ARG}

  is_agent_container_running "${test_container_name}"

  run_through_ssh "${test_container_name}" echo f00
  assert_success
  assert_equal "${output}" "f00"

  clean_test_container "${test_container_name}"
}

@test "[${SUT_IMAGE}] create agent container with '${DOCKER_PLUGIN_DEFAULT_ARG}' (quoted) as argument" {
  [ -n "$DOCKER_PLUGIN_DEFAULT_ARG" ]

  local test_container_name=${AGENT_CONTAINER}-docker-plugin-quoted
  clean_test_container "${test_container_name}"
  docker run -e "JENKINS_AGENT_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${test_container_name}" -P "${SUT_IMAGE}" "${DOCKER_PLUGIN_DEFAULT_ARG}"

  is_agent_container_running "${test_container_name}"

  run_through_ssh "${test_container_name}" echo f00
  assert_success
  assert_equal "${output}" "f00"

  clean_test_container "${test_container_name}"
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

  local test_container_name=${AGENT_CONTAINER}-build-args
  clean_test_container "${test_container_name}"
  docker run -d --name "${test_container_name}" -P "${sut_image}" "${PUBLIC_SSH_KEY}"

  run docker exec "${test_container_name}" sh -c "id -u -n ${TEST_USER}"
  assert_line --index 0 "${TEST_USER}"
  run docker exec "${test_container_name}" sh -c "id -g -n ${TEST_USER}"
  assert_line --index 0 "${TEST_GROUP}"
  run docker exec "${test_container_name}" sh -c "id -u ${TEST_USER}"
  assert_line --index 0 "${TEST_UID}"
  run docker exec "${test_container_name}" sh -c "id -g ${TEST_USER}"
  assert_line --index 0 "${TEST_GID}"
  run docker exec "${test_container_name}" sh -c 'stat -c "%U:%G" "${JENKINS_AGENT_HOME}"'
  assert_line --index 0 "${TEST_USER}:${TEST_GROUP}"

  clean_test_container "${test_container_name}"
}

@test "[${SUT_IMAGE}] has utf-8 locale" {
  if [[ "${SUT_IMAGE}" == *"alpine"*  ]]; then
    run docker run --entrypoint sh --rm "${SUT_IMAGE}" -c '/usr/glibc-compat/bin/locale charmap'
  else
    run docker run --entrypoint sh --rm "${SUT_IMAGE}" -c 'locale charmap'
  fi
  assert_equal "${output}" "UTF-8"
}
