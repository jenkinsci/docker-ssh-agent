#!/bin/bash
# check dependencies
(
    type docker &>/dev/null || ( echo "docker is not available"; exit 1 )
    type curl &>/dev/null || ( echo "curl is not available"; exit 1 )
    type ssh &>/dev/null || ( echo "ssh is not available"; exit 1 )
)>&2

# Assert that $1 is the output of a command $2
function assert {
    local expected_output=$1
    shift
    actual_output=$("$@")
    if ! [ "$actual_output" = "$expected_output" ]; then
        echo "expected: \"$expected_output\", actual: \"$actual_output\""
        false
    fi
}

# Retry a command $1 times until it succeeds. Wait $2 seconds between retries.
function retry {
    local attempts=$1
    shift
    local delay=$1
    shift
    local i

    for ((i=0; i < attempts; i++)); do
        run "$@"
        if [ "$status" -eq 0 ]; then
            return 0
        fi
        sleep $delay
    done

    echo "Command \"$@\" failed $attempts times. Status: $status. Output: $output"
    false
}

# return the published port for given container port $1
function get_port {
    docker port $SUT_CONTAINER $1 | cut -d: -f2
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
