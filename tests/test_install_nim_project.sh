#!/bin/bash

# Test the install_nim_project function

source setup.sh

source ../nim-ci.sh

NIM_PROJECT_DIR="$(cd nim_projects/nimcilibrary; pwd)"
collect_project_metadata
install_nim_project
# assert that `nimble develop` was used
assert "$(head -n 1 "${NIMBLE_DIR}/pkgs/nimcilibrary-#head/nimcilibrary.nimble-link")" \
  == "${NIM_PROJECT_DIR}/nimcilibrary.nimble"
assert "$(tail -n 1 "${NIMBLE_DIR}/pkgs/nimcilibrary-#head/nimcilibrary.nimble-link")" \
  == "${NIM_PROJECT_DIR}/src"

NIM_PROJECT_DIR="$(cd nim_projects/nested/nimcihybrid; pwd)"
collect_project_metadata
install_nim_project
assert_type -p "${NIMBLE_DIR}/bin/nimcihybrid1"
assert_type -p "${NIMBLE_DIR}/bin/nimcihybrid2"
assert -f "${NIMBLE_DIR}/pkgs/nimcihybrid-0.1.0/nimcihybridpkg/nimcihybridpkg.nim"

NIM_PROJECT_DIR="$(cd nim_projects/nested/nimcibinary; pwd)"
collect_project_metadata
install_nim_project
assert_type -p "${NIMBLE_DIR}/bin/nimcibinary1"
assert_type -p "${NIMBLE_DIR}/bin/nimcibinary2"
