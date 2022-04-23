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
function assert {
    local expected_output
    local actual_output
    expected_output="${1}"
    shift
    actual_output=$("${@}")
    if ! [[ "${actual_output}" = "${expected_output}" ]]; then
        printMessage "Expected: '${expected_output}', actual: '${actual_output}'"
        false
    fi
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
        if [[ "${status}" -eq 0 ]]; then
            return 0
        fi
        sleep "${delay}"
    done

    printMessage "Command '${*}' failed $attempts times. Status: ${status}. Output: ${output}"

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
  echo "*** SSH_PORT is ${SSH_PORT}"
	if [[ "${SSH_PORT}" = "" ]]; then
		printMessage "failed to get SSH port"
		false
	else
		TMP_PRIV_KEY_FILE=$(mktemp "${BATS_TMPDIR}"/bats_private_ssh_key_XXXXXXX)
		echo "*** TMP_PRIV_KEY_FILE is ${TMP_PRIV_KEY_FILE}"
		echo "${PRIVATE_SSH_KEY}" > "${TMP_PRIV_KEY_FILE}" \
		 	&& chmod 0600 "${TMP_PRIV_KEY_FILE}"

		echo "*** Running ssh command"
		run ssh -i "${TMP_PRIV_KEY_FILE}" \
			-o LogLevel=quiet \
			-o UserKnownHostsFile=/dev/null \
			-o StrictHostKeyChecking=no \
			-l jenkins \
			127.0.0.1 \
			-p "${SSH_PORT}" \
			"${@}"

		rm -f "${TMP_PRIV_KEY_FILE}"
	fi
}

function clean_test_container {
  local agent_container=$1
  docker kill "${agent_container}" &>/dev/null ||:
  docker rm -fv "${agent_container}" &>/dev/null ||:
}

function is_agent_container_running {
  local agent_container=$1
	sleep 1  # give time to sshd to eventually fail to initialize
	retry 3 1 assert "true" docker inspect -f '{{.State.Running}}' "${agent_container}"
}
