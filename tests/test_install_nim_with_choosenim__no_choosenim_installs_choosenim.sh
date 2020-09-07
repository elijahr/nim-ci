#!/bin/bash

# Test that the install_nim_with_choosenim function installs choosenim
# if it is not installed.

source setup.sh

INIT_NIM_CI=no

source ../nim-ci.sh

if [[ "$HOST_CPU" != "amd64" ]]
then
  echo "Test skipped"
  exit $RET_SKIP
fi

install_nim_with_choosenim

assert_type -p choosenim
