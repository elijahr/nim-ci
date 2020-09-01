# Package
version       = "0.1.0"
author        = "Elijah Shaw-Rutschman"
description   = "Meta-package for testing nim-ci"
license       = "MIT"
srcDir        = "src"
bin           = @["nimcitester"]
binDir        = "bin"

requires "nim >= 0.16.0"

before install:
  for pkg in ["nimcibinary", "nimcihybrid", "nimcilibrary"]:
    withDir pkg:
      exec "nimble install -y"

task test, "Runs the test suite":
  withDir "src":
    exec "nim c -r nimcitester.nim"
