#!/bin/bash

# Test that the install_nim_nightly_or_build_nim function downloads a nightly
# builds of nim if NIM_VERSION is devel.

source setup.sh

INIT_NIM_CI=no
DOWNLOADED_NIGHTLY=no

source ../nim-ci.sh

# Mock download_nightly
download_nightly () {
  DOWNLOADED_NIGHTLY=yes
  return $RET_OK
}

install_nim_nightly_or_build_nim

assert "$DOWNLOADED_NIGHTLY" == "yes"

