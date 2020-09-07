#!/bin/bash

# Run all the test scripts in this directory

cd "$(dirname "$0")"

source ./setup.sh

rm -f /tmp/nim-ci-test-log.txt
FAILED=no
CANCELLED=no

cleanup_all () {
  rm -f /tmp/nim-ci-test-log.txt
}

on_cancel () {
  export CANCELLED=yes
}

trap cleanup_all EXIT

trap on_cancel INT

for TEST in test_*.sh
do
  echo "[RUNNING] $TEST"
  if [[ "$CANCELLED" == "no" ]]
  then
    echo >> /tmp/nim-ci-test-log.txt
    echo ">>> $TEST >>>" >> /tmp/nim-ci-test-log.txt
    echo >> /tmp/nim-ci-test-log.txt
    bash "$TEST" >> /tmp/nim-ci-test-log.txt 2>&1 && RET=$? || RET=$?
    echo >> /tmp/nim-ci-test-log.txt
    echo "<<< $TEST <<<" >> /tmp/nim-ci-test-log.txt
    echo >> /tmp/nim-ci-test-log.txt
    case $RET in
      $RET_PASS) STATUS="${GREEN}[✅ PASS]${NC}" ;;
      $RET_SKIP) STATUS="${GRAY}[ ✔ SKIP]${NC}" ;;
      *)
        STATUS="${RED}[❌ FAIL]${NC}"
        FAILED=yes
        ;;
    esac
  else
    STATUS="${RED}[CANCELLED]${NC}"
    FAILED=yes
  fi
  echo -e "$STATUS ${TEST}"
done

if [[ "$FAILED" == "yes" ]]
then
  echo
  echo "===== collected output ====="
  echo
  cat /tmp/nim-ci-test-log.txt
  exit 1
fi
