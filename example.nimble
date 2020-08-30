import strutils

# Package
version       = "0.1.0"
author        = "me"
description   = "stuff"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["example"]

# Dependencies
requires "nim >= 1.2.4"

task test, "Runs the test suite (C & C++)":
  exec "nim c -r tests/test.nim"
  exec "nim cpp -r tests/test.nim"
