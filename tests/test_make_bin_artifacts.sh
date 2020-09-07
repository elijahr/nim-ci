#!/bin/bash

# Test the make_bin_artifacts function

source setup.sh

NIM_PROJECT_DIR="$(cd nim_projects/nested/nimcibinary; pwd)"

source ../nim-ci.sh

cleanup () {
  rm -rf "${NIM_PROJECT_DIR}/bin"
}

trap cleanup EXIT

mkdir -p "${NIM_PROJECT_DIR}/bin"
echo "this is an artifact" >> "${NIM_PROJECT_DIR}/bin/artifact${BIN_EXT}"

make_bin_artifacts

ARTIFACT="${ARTIFACTS_DIR}/artifact-0.1.0-${HOST_OS}_${HOST_CPU}${BIN_EXT}"
assert -f "$ARTIFACT"
assert "$(cat "$ARTIFACT")" == "this is an artifact"
