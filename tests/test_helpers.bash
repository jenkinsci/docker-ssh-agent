#!/usr/bin/env bash

set -eu

# check dependencies
(
    type docker &>/dev/null || ( echo "docker is not available"; exit 1 )
    type curl &>/dev/null || ( echo "curl is not available"; exit 1 )
    type ssh &>/dev/null || ( echo "ssh is not available"; exit 1 )
)>&2

function printMessage {
  echo "# ${@}" >&3
}

# Assert that $1 is the output of a command $2
function assert_run_cmd_output_equal {
    local expected_output
    local actual_output
    expected_output="${1}"
    shift
    run "${@}"
    assert_output "${expected_output}"
}

function get_sut_image {
    test -n "${IMAGE:?"[sut_image] Please set the variable 'IMAGE' to the name of the image to test in 'docker-bake.hcl'."}"
    ## Retrieve the SUT image name from buildx
    # Option --print for 'docker buildx bake' prints the JSON configuration on the stdout
    # Option --silent for 'make' suppresses the echoing of command so the output is valid JSON
    # The image name is the 1st of the "tags" array, on the first "image" found
    make --silent show | jq -r ".target.${IMAGE}.tags[0]"
}

# Retry a command $1 times until it succeeds. Wait $2 seconds between retries.
# Command is passed as the "rest" of arguments: $3 $4 $5 ...
function retry {
    local attempts
    local delay
    local i
    attempts="${1}"
    shift
    delay="${1}"
    shift

    for ((i=0; i < attempts; i++)); do
        run "${@}"
        if assert_success; then
            return 0
        fi
        sleep "${delay}"
    done

    printMessage "Command '${BATS_RUN_COMMAND}' failed ${attempts} times. Status: ${status}. Output: ${output}"

    false
}

# return the published port for given container port $1
function get_port {
  local agent_container_name="${1}"
  local port="${2}"
  docker port "${agent_container_name}" "${port}" | cut -d: -f2
}

# run a given command through ssh on the test container.
# Use the $status, $output and $lines variables to make assertions
function run_through_ssh {
  local agent_container_name="${1}"
  shift 1
  SSH_PORT=$(get_port "${agent_container_name}" 22)
	if [[ "${SSH_PORT}" = "" ]]; then
		printMessage "failed to get SSH port"
		false
	else
		TMP_PRIV_KEY_FILE=$(mktemp "${BATS_TMPDIR}"/bats_private_ssh_key_XXXXXXX)
		echo "${PRIVATE_SSH_KEY}" > "${TMP_PRIV_KEY_FILE}" \
			&& chmod 0600 "${TMP_PRIV_KEY_FILE}"

		echo "[DEBUG] *** Running ssh command"
		run ssh -i "${TMP_PRIV_KEY_FILE}" \
			-o LogLevel=quiet \
			-o UserKnownHostsFile=/dev/null \
			-o StrictHostKeyChecking=no \
			-l jenkins \
			127.0.0.1 \
			-p "${SSH_PORT}" \
			"${@}"
    echo "[DEBUG] *** Command was: ${BATS_RUN_COMMAND}"

		rm -f "${TMP_PRIV_KEY_FILE}"
	fi
}

function clean_test_container {
  local agent_container=$1
  docker kill "${agent_container}" &>/dev/null ||:
  docker rm --force --volumes "${agent_container}" &>/dev/null ||:
}

function is_agent_container_running {
  local agent_container=$1
  # 30s is considered enough for the SSH server to start, even under constraint
	retry 15 2 assert_run_cmd_output_equal healthy docker inspect -f '{{.State.Health.Status}}' "${agent_container}"
}
