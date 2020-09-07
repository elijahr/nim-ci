#!/bin/bash

# Test the collect_project_metadata function

source setup.sh

source ../nim-ci.sh

export NIM_PROJECT_DIR="$(cd nim_projects/nimcilibrary; pwd)"
collect_project_metadata
assert "$SRC_DIR" == "${NIM_PROJECT_DIR}/src"
assert "$NIM_PROJECT_TYPE" == "library"
assert -z "$BIN_DIR"

export NIM_PROJECT_DIR="$(cd nim_projects/nested/nimcihybrid; pwd)"
collect_project_metadata
assert "$SRC_DIR" == "${NIM_PROJECT_DIR}/src"
assert "$NIM_PROJECT_TYPE" == "hybrid"
assert "$BIN_DIR" == "${NIM_PROJECT_DIR}/bin"

# Test with explicit path
export OTHER_NIM_PROJECT_DIR="$(cd nim_projects/nested/nimcibinary; pwd)"
collect_project_metadata "$OTHER_NIM_PROJECT_DIR"
assert "$NIM_PROJECT_DIR" == "$OTHER_NIM_PROJECT_DIR"
assert "$SRC_DIR" == "${OTHER_NIM_PROJECT_DIR}/src"
assert "$NIM_PROJECT_TYPE" == "binary"
assert "$BIN_DIR" == "${OTHER_NIM_PROJECT_DIR}/bin"

