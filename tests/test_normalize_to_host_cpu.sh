#!/bin/bash

# Test the normalize_to_host_cpu function

source setup.sh

INIT_NIM_CI=no
source ../nim-ci.sh

assert "$(normalize_to_host_cpu x86_64)" == "amd64"
assert "$(normalize_to_host_cpu x64)" == "amd64"
assert "$(normalize_to_host_cpu amd64)" == "amd64"

assert "$(normalize_to_host_cpu x86)" == "i386"
assert "$(normalize_to_host_cpu x32)" == "i386"
assert "$(normalize_to_host_cpu i386)" == "i386"

assert "$(normalize_to_host_cpu ppc64le)" == "powerpc64el"
assert "$(normalize_to_host_cpu powerpc64el)" == "powerpc64el"

assert "$(normalize_to_host_cpu armv6)" == "arm"
assert "$(normalize_to_host_cpu armv7)" == "arm"
assert "$(normalize_to_host_cpu arm)" == "arm"

assert "$(normalize_to_host_cpu aarch64)" == "arm64"
assert "$(normalize_to_host_cpu arm64)" == "arm64"
