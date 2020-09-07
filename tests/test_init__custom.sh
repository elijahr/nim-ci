#!/bin/bash

# Test the init function with custom variables set

source setup.sh

USE_CHOOSENIM=no
NIM_VERSION="1.2.4"
NIM_PROJECT_DIR="$(cd nim_projects/nested/nimcibinary; pwd)"

source ../nim-ci.sh

# Assert that the correct version of nim was installed
assert "$(installed_nim_version)" == "1.2.4"

assert "$ARTIFACTS_DIR" == "${NIM_PROJECT_DIR}/artifacts"
assert "$BIN_DIR" == "${NIM_PROJECT_DIR}/bin"
[[ "$HOST_OS" == "windows" ]] && assert "$BIN_EXT" == ".exe" || assert -z "$BIN_EXT"
assert "$NIM_PROJECT_NAME" == "nimcibinary"
assert "$NIM_PROJECT_TYPE" == "binary"
assert "$SRC_DIR" == "${NIM_PROJECT_DIR}/src"
assert "$USE_CHOOSENIM" == "no"
