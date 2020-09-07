#!/bin/bash

# Test the normalize_to_host_os function

source setup.sh

INIT_NIM_CI="no"
source ../nim-ci.sh

assert "$(normalize_to_host_os ubuntu18.04)" == "linux"
assert "$(normalize_to_host_os alpine_latest)" == "linux"
assert "$(normalize_to_host_os jessie)" == "linux"
assert "$(normalize_to_host_os buster)" == "linux"
assert "$(normalize_to_host_os stretch)" == "linux"
assert "$(normalize_to_host_os arch)" == "linux"
assert "$(normalize_to_host_os gentoo)" == "linux"
assert "$(normalize_to_host_os fedora)" == "linux"
assert "$(normalize_to_host_os manjaro)" == "linux"
assert "$(normalize_to_host_os linux)" == "linux"

assert "$(normalize_to_host_os darwin)" == "macosx"
assert "$(normalize_to_host_os macos)" == "macosx"
assert "$(normalize_to_host_os osx)" == "macosx"
assert "$(normalize_to_host_os macosx)" == "macosx"

assert "$(normalize_to_host_os mingw)" == "windows"
assert "$(normalize_to_host_os msys)" == "windows"
assert "$(normalize_to_host_os windows)" == "windows"
