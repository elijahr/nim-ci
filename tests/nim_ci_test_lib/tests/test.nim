import unittest

import nim_ci_test

suite "nim_ci_test_lib":
  test "nim_ci_test_lib library was installed and imported correctly":
    check NIM_CI_TEST_LIB
