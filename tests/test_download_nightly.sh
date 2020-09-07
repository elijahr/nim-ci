#!/bin/bash

# Test the download_nightly function

source setup.sh

INIT_NIM_CI=no

source ../nim-ci.sh

download_nightly
assert "$?" == "$RET_OK"

DEVEL_BIN_DIR="${CHOOSENIM_DIR}/toolchains/nim-#devel/bin"
assert "${PATH:0:${#DEVEL_BIN_DIR}}" == "$DEVEL_BIN_DIR"
