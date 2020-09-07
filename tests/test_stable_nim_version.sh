#!/bin/bash

# Test the stable_nim_version function

source setup.sh

INIT_NIM_CI=no
source ../nim-ci.sh

[[ "$(stable_nim_version)" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
