#!/usr/bin/env bats

load test_helpers

SUT_DESCRIPTION="tags"

@test "[${SUT_DESCRIPTION}] Default tags unchanged" {
  assert_matches_golden expected_tags make --silent tags
}
