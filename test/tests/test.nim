import osproc
import system
import unittest

import nim_ci_test

suite "test":
  test "assert that first executable was built and can run":
    let (output, exitCode) = execCmdEx("./" & hostOS & "_" & hostCPU & "/nim_ci_exe_1")
    check exitCode == 0
    check output == "nim_ci_test_exe_1"

  test "assert that second executable was built and can run":
    let (output, exitCode) = execCmdEx("./" & hostOS & "_" & hostCPU & "/nim_ci_exe_2")
    check exitCode == 0
    check output == "nim_ci_test_exe_2"

  test "nim_ci_test library was installed and imported correctly":
    check NIM_CI_TEST_LIB
