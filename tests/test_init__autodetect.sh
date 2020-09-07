#!/bin/bash

# Test the init function - autodetction

source setup.sh

unset NIM_VERSION

source ../nim-ci.sh

assert "$(installed_nim_version)" == "$(stable_nim_version)"
assert "$ARTIFACTS_DIR" == "${NIM_PROJECT_DIR}/artifacts"
assert -z "$BIN_DIR"
[[ "$HOST_OS" == "windows" ]] && assert "$BIN_EXT" == ".exe" || assert -z "$BIN_EXT"
# Assert that the lowest-hierarchy nim project is auto-detected
assert "$NIM_PROJECT_DIR" == "$(cd nim_projects/nimcilibrary; pwd)"
assert "$NIM_PROJECT_NAME" == "nimcilibrary"
assert "$NIM_PROJECT_TYPE" == "library"
assert "$SRC_DIR" == "${NIM_PROJECT_DIR}/src"
[[ "$HOST_CPU" == "amd64" ]] && assert "$USE_CHOOSENIM" == "yes" || assert "$USE_CHOOSENIM" == "no"
