#!/bin/bash

# Test the installed_nim_version function

source setup.sh

INIT_NIM_CI=no
source ../nim-ci.sh

# Mock nim
nim () {
  cat << EOF
Nim Compiler Version 1.2.6 [MacOSX: amd64]
EOF
}

# Mock other nim
cat << EOF > othernim
#!/bin/bash
echo "Nim Compiler Version 1.2.4 [MacOSX: amd64]"
EOF
chmod +x othernim

add_path .

cleanup () {
  rm -f built.txt
  rm -f othernim
}

trap cleanup EXIT

assert "$(installed_nim_version)" == "1.2.6"
assert "$(installed_nim_version ./othernim)" == "1.2.4"
