#!/bin/bash

# Test that the install_nim_nightly_or_build_nim function builds nim if nim is
# not installed.

source setup.sh

INIT_NIM_CI=no
NIM_VERSION=1.2.6

source ../nim-ci.sh

# Mock download_nightly
download_nightly () {
  fail "Unexpected call to download_nightly"
}

# Mock curl
curl () {
  DIR=$(pwd)
  mkdir -p "${CHOOSENIM_DIR}/tmp"
  cd "${CHOOSENIM_DIR}/tmp"
  mkdir -p nim-lang-Nim-a5a0a9e
  echo "#!/bin/sh" > nim-lang-Nim-a5a0a9e/build_all.sh
  echo "echo yes > '${CHOOSENIM_DIR}/tmp/nim-was-built.txt'" >> nim-lang-Nim-a5a0a9e/build_all.sh
  tar czf ${DIR}/Nim.tar.gz nim-lang-Nim-a5a0a9e
  cd - &>/dev/null
}

install_nim_nightly_or_build_nim

assert "$(cat "${CHOOSENIM_DIR}/tmp/nim-was-built.txt")" == "yes"
EXPECTED_PATH_FRONT="${CHOOSENIM_DIR}/toolchains/nim-1.2.6-${HOST_CPU}/bin:"
assert "${PATH:0:${#EXPECTED_PATH_FRONT}}" == "$EXPECTED_PATH_FRONT"

