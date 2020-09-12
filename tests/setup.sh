#!/bin/bash

set -ueo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

RET_PASS=0
RET_FAIL=1
RET_SKIP=2

ASSERT_FAILED=0

TMP_DIR="$(mktemp -d ${TMPDIR:-'/tmp'}/nim-ci-XXXXXXX)"
CHOOSENIM_DIR="${TMP_DIR}/choosenim"
NIMBLE_DIR="${TMP_DIR}/nimble"
PATH="${NIMBLE_DIR}/bin:$PATH"

CHOOSENIM_ARGS="--choosenimDir:${CHOOSENIM_DIR} --nimbleDir:${NIMBLE_DIR}"

# Default to using nightly builds for faster test runs
NIM_VERSION=devel

mkdir -p "$CHOOSENIM_DIR"
mkdir -p "$NIMBLE_DIR"

on_exit () {
  rm -rf "$TMP_DIR"
  if [[ "${NIM_CI_TEST_FULL_CLEAN:-no}" == "yes" ]]
  then
    # On CI, start with a clean slate between each test
    rm -rf "${HOME}/.nimble"
    rm -rf "${HOME}/.nim"
    rm -rf "${HOME}/.choosenim"
    rm -rf "${HOME}/.cache/nim"
    rm -rf "${HOME}/.cache/nim-ci"
  fi
  if [[ "$ASSERT_FAILED" != 0 ]]
  then
    exit $ASSERT_FAILED
  fi
}

trap on_exit EXIT

join_string_array () {
  # Join elements of a bash array (second arg) with a delimiter (first arg) and
  # echo the result.
  local d=$1;
  shift;
  local f=$1;
  shift;
  printf %s "$f" "${@/#/$d}";
}

fail () {
  ASSERT_FAILED=1
  echo "❌ $1"
  exit 1
}

assert () {
  set +e
  if [[ "$1" == "[[" ]]
  then
    case ${#@} in
      4) eval "[[ $2 '$3' ]]" ;;
      5) eval "[[ '$2' $3 '$4' ]]" ;;
      *) fail "Unhandled number of arguments: $@" ;;
    esac
  else
    case ${#@} in
      1) test "$1" ;;
      2) test "$1" "$2" ;;
      3) test "$1" "$2" "$3" ;;
      4) test "$1" "$2" "$3" "$4" ;;
      *) fail "Unhandled number of arguments: $@" ;;
    esac
  fi
  STAT=$?
  set -e
  case $STAT in
    0) printf "✅" ;;
    *) ASSERT_FAILED=$STAT; printf "❌" ;;
  esac
  printf " assert $(join_string_array " " $@)"
  echo
}

assert_type () {
  set +e
  type "$1" "$2"
  STAT=$?
  set -e
  case $STAT in
    0) printf "✅" ;;
    *) ASSERT_FAILED=$STAT; printf "❌" ;;
  esac
  printf " assert_type $(join_string_array " " $@)"
  echo
}
