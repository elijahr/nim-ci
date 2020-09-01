import strutils

# Package
version       = "0.1.0"
author        = "Elijah Shaw-Rutschman"
description   = "Package for testing nim-ci"
license       = "MIT"
srcDir        = "src"
binDir        = "bin"
bin           = @["nimcibinary1", "nimcibinary2"]
skipExt       = @["nim"]

# Dependencies
requires "nim >= 0.16.0"

