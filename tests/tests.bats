#!/usr/bin/env bats

DOCKERFILE=Dockerfile
SUT_IMAGE=jenkins-ssh-slave
SUT_CONTAINER=bats-jenkins-ssh-slave

if [[ -z "${FLAVOR}" ]]
then
  FLAVOR="debian"
else
  DOCKERFILE+="-alpine"
  SUT_IMAGE+=":alpine"
  SUT_CONTAINER+="-alpine"
fi

load test_helpers
load keys

clean_test_container

@test "[${FLAVOR}] build image" {
  cd "${BATS_TEST_DIRNAME}"/.. || false
  docker build -t "${SUT_IMAGE}" -f "${DOCKERFILE}" .
}

@test "[${FLAVOR}] checking image metadata" {
  local VOLUMES_MAP="$(docker inspect -f '{{.Config.Volumes}}' ${SUT_IMAGE})"

  echo "${VOLUMES_MAP}" | grep '/tmp'
  echo "${VOLUMES_MAP}" | grep '/home/jenkins'
  echo "${VOLUMES_MAP}" | grep '/run'
  echo "${VOLUMES_MAP}" | grep '/var/run'
}

@test "[${FLAVOR}] image has bash and java installed and in the PATH" {
  docker run -d --name "${SUT_CONTAINER}" -P "${SUT_IMAGE}" "${PUBLIC_SSH_KEY}"

  docker exec "${SUT_CONTAINER}" which bash
  docker exec "${SUT_CONTAINER}" bash --version
  docker exec "${SUT_CONTAINER}" which java
  docker exec "${SUT_CONTAINER}" java -version

  clean_test_container
}

@test "[${FLAVOR}] create slave container with pubkey as argument" {
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

@test "[${FLAVOR}] create slave container with pubkey as environment variable" {
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

@test "[${FLAVOR}] use build args correctly" {
  cd "${BATS_TEST_DIRNAME}"/.. || false

	local TEST_USER=test-user
	local TEST_GROUP=test-group
	local TEST_UID=2000
	local TEST_GID=3000
	local TEST_JAH=/home/something

  docker build \
    --build-arg "user=${TEST_USER}" \
    --build-arg "group=${TEST_GROUP}" \
    --build-arg "uid=${TEST_UID}" \
    --build-arg "gid=${TEST_GID}" \
    --build-arg "JENKINS_AGENT_HOME=${TEST_JAH}" \
    -t "${SUT_IMAGE}" \
    -f "${DOCKERFILE}" .

  docker run -d --name "${SUT_CONTAINER}" -P "${SUT_IMAGE}" "${PUBLIC_SSH_KEY}"

  RESULT=$(docker exec "${SUT_CONTAINER}" sh -c "id -u -n ${TEST_USER}")
  [ "${RESULT}" = "${TEST_USER}" ]
  RESULT=$(docker exec "${SUT_CONTAINER}" sh -c "id -g -n ${TEST_USER}")
  [ "${RESULT}" = "${TEST_GROUP}" ]
  RESULT=$(docker exec "${SUT_CONTAINER}" sh -c "id -u ${TEST_USER}")
  [ "${RESULT}" = "${TEST_UID}" ]
  RESULT=$(docker exec "${SUT_CONTAINER}" sh -c "id -g ${TEST_USER}")
  [ "${RESULT}" = "${TEST_GID}" ]
  RESULT=$(docker exec "${SUT_CONTAINER}" sh -c 'stat -c "%U:%G" "${JENKINS_AGENT_HOME}"')
  [ "${RESULT}" = "${TEST_USER}:${TEST_GROUP}" ]

  clean_test_container
}
