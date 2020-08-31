import strutils

# Package
version       = "0.1.0"
author        = "Elijah Shaw-Rutschman"
description   = "Package for testing nim-ci"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["nim_ci_test_bin_1", "nim_ci_test_bin_2"]

# Dependencies
requires "nim >= 0.16.0"

task test, "Runs the test suite":
  withDir "tests":
    exec "nim c -r test.nim"
