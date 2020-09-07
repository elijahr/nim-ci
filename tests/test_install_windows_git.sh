#!/bin/bash

# Test the install_windows_git function

source setup.sh

INIT_NIM_CI=no
source ../nim-ci.sh

if [[ "$HOST_OS" != "windows" ]]
then
  echo "Test skipped"
  exit $RET_SKIP
fi

install_windows_git

assert -p git

