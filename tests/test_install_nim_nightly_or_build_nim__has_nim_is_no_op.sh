#!/bin/bash

# Test that the install_nim_nightly_or_build_nim function does not build nim if
# a cached nim is found.

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
  fail "Unexpected call to curl: $@"
}

# Mock nim
NIM="${CHOOSENIM_DIR}/toolchains/nim-1.2.6-${HOST_CPU}/bin/nim"
mkdir -p "$(dirname "$NIM")"
cat << EOF > "$NIM"
#!/bin/bash
echo "Nim Compiler Version 1.2.6 [MacOSX: amd64]"
EOF
chmod +x "$NIM"

cleanup () {
  rm -Rf "${CHOOSENIM_DIR}/toolchains"
}

trap cleanup EXIT

assert "$(install_nim_nightly_or_build_nim)" == "Using cached Nim $NIM"
