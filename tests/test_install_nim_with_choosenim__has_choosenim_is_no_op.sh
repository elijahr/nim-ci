#!/bin/bash

# Test that the install_nim_with_choosenim function does not install choosenim
# if it is already installed.

source setup.sh

INIT_NIM_CI=no

source ../nim-ci.sh

if [[ "$HOST_CPU" != "amd64" ]]
then
  echo "Test skipped"
  exit $RET_SKIP
fi

cleanup () {
  rm -Rf "${NIMBLE_DIR}/bin/choosenim"
}

trap cleanup EXIT

# Mock choosenim
mkdir -p "${NIMBLE_DIR}/bin"
echo "#!/bin/bash" > "${NIMBLE_DIR}/bin/choosenim"
chmod +x "${NIMBLE_DIR}/bin/choosenim"

install_nim_with_choosenim

assert -p choosenim
