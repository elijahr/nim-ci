#!/bin/bash

# Test the add_path function

source setup.sh

INIT_NIM_CI=no
source ../nim-ci.sh

add_path /some/path
assert "${PATH:0:11}" == "/some/path:"

GITHUB_WORKFLOW="some-workflow"
OUTPUT=$(add_path /some/other/path)
assert "$OUTPUT" == "::add-path::/some/other/path"
