import strutils

# Package
version       = "0.1.0"
author        = "test"
description   = "test"
license       = "test"
srcDir        = "src"
binDir        = "bin"
bin           = @["test"]

# Dependencies
requires "nim >= 1.2.4"

task test, "Runs the test suite (C & C++)":
  exec "nim c -r tests/test.nim"
  exec "nim cpp -r tests/test.nim"
