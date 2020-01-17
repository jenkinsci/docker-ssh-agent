#!/usr/bin/env bats

DOCKERFILE=Dockerfile
JDK=8
SLAVE_IMAGE=jenkins-ssh-slave
SLAVE_CONTAINER=bats-jenkins-ssh-slave

if [[ -z "${FLAVOR}" ]]
then
  FLAVOR="debian"
elif [[ "${FLAVOR}" = "jdk11" ]]
then
  DOCKERFILE+="-jdk11"
  JDK=11
  SLAVE_IMAGE+=":jdk11"
  SLAVE_CONTAINER+="-jdk11"
else
  DOCKERFILE+="-alpine"
  SLAVE_IMAGE+=":alpine"
  SLAVE_CONTAINER+="-alpine"
fi

load test_helpers
load keys

clean_test_container

function teardown () {
  clean_test_container
}

@test "[${FLAVOR}] build image" {
  cd "${BATS_TEST_DIRNAME}"/.. || false
  docker build -t "${SLAVE_IMAGE}" -f "${DOCKERFILE}" .
}

@test "[${FLAVOR}] checking image metadata" {
  local VOLUMES_MAP
  VOLUMES_MAP="$(docker inspect -f '{{.Config.Volumes}}' ${SLAVE_IMAGE})"

  echo "${VOLUMES_MAP}" | grep '/tmp'
  echo "${VOLUMES_MAP}" | grep '/home/jenkins'
  echo "${VOLUMES_MAP}" | grep '/run'
  echo "${VOLUMES_MAP}" | grep '/var/run'
}

@test "[${FLAVOR}] image has bash and java installed and in the PATH" {
  docker run -d --name "${SLAVE_CONTAINER}" -P "${SLAVE_IMAGE}" "${PUBLIC_SSH_KEY}"

  run docker exec "${SLAVE_CONTAINER}" which bash
  [ "${status}" -eq 0 ]
  run docker exec "${SLAVE_CONTAINER}" bash --version
  [ "${status}" -eq 0 ]
  run docker exec "${SLAVE_CONTAINER}" which java
  [ "${status}" -eq 0 ]

  if [[ "${JDK}" -eq 8 ]]
  then
    run docker exec "${SLAVE_CONTAINER}" sh -c "
    java -version 2>&1 \
      | grep -o -E '^openjdk version \"[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+.*\"' \
      | grep -o -E '\.[[:digit:]]+\.' \
      | grep -o -E '[[:digit:]]+'
    "
  else
    run docker exec "${SLAVE_CONTAINER}" sh -c "
    java -version 2>&1 \
      | grep -o -E '^openjdk version \"[[:digit:]]+\.' \
      | grep -o -E '\"[[:digit:]]+\.' \
      | grep -o -E '[[:digit:]]+'
    "
  fi
  [ "${JDK}" = "${lines[0]}" ]
}

@test "[${FLAVOR}] create slave container with pubkey as argument" {
  docker run -d --name "${SLAVE_CONTAINER}" -P "${SLAVE_IMAGE}" "${PUBLIC_SSH_KEY}"

  is_slave_container_running

  run_through_ssh echo f00

  [ "$status" = "0" ] && [ "$output" = "f00" ] \
    || (\
      echo "status: $status"; \
      echo "output: $output"; \
      false \
    )
}

@test "[${FLAVOR}] create slave container with pubkey as environment variable" {
  docker run -e "JENKINS_SLAVE_SSH_PUBKEY=${PUBLIC_SSH_KEY}" -d --name "${SLAVE_CONTAINER}" -P "${SLAVE_IMAGE}"

  is_slave_container_running

  run_through_ssh echo f00

  [ "$status" = "0" ] && [ "$output" = "f00" ] \
    || (\
      echo "status: $status"; \
      echo "output: $output"; \
      false \
    )
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
    -t "${SLAVE_IMAGE}" \
    -f "${DOCKERFILE}" .

  docker run -d --name "${SLAVE_CONTAINER}" -P "${SLAVE_IMAGE}" "${PUBLIC_SSH_KEY}"

  run docker exec "${SLAVE_CONTAINER}" sh -c "id -u -n ${TEST_USER}"
  [ "${TEST_USER}" = "${lines[0]}" ]
  run docker exec "${SLAVE_CONTAINER}" sh -c "id -g -n ${TEST_USER}"
  [ "${TEST_GROUP}" = "${lines[0]}" ]
  run docker exec "${SLAVE_CONTAINER}" sh -c "id -u ${TEST_USER}"
  [ "${TEST_UID}" = "${lines[0]}" ]
  run docker exec "${SLAVE_CONTAINER}" sh -c "id -g ${TEST_USER}"
  [ "${TEST_GID}" = "${lines[0]}" ]
  run docker exec "${SLAVE_CONTAINER}" sh -c 'stat -c "%U:%G" "${JENKINS_AGENT_HOME}"'
  [ "${TEST_USER}:${TEST_GROUP}" = "${lines[0]}" ]
}
