#!/bin/sh

set -ex

# Install system packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -q -y build-essential git curl

# Checkout repo
ref=`basename $GITHUB_REF`
git clone -b $ref --single-branch "https://github.com/${GITHUB_REPOSITORY}.git" repo

# Find nim project in repo
project_dir=`dirname $(find repo -type f -name "*.nimble" -print -quit)`
cd $project_dir

# Install nim
export NIM_VERSION=${{ matrix.nim_version }}
export CPU_ARCH=${{ matrix.arch }}
export OS_NAME=linux
curl https://raw.githubusercontent.com/elijahr/nim-ci/github-workflows/install_nim.sh -LsSf -o install_nim.sh
source install_nim.sh

# TODO - include this in install_nim.sh
curl https://raw.githubusercontent.com/elijahr/nim-ci/github-workflows/build_project.sh -LsSf -o build_project.sh
source build_project.sh

# Run tests
nimble test

# Export binary, if configured
if [[ ! -z "$BIN" ]]
then
  echo ::set-output name=binary_name::$BIN
  echo ::set-output name=binary::$(cat "${BIN_DIR}/${BIN}")
fi
