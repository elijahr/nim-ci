
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
  # find nim-ci.sh
  var nimcish = ""
  for dir in [getCurrentDir(), getCurrentDir()&"/../..", getCurrentDir()&"/../../.."]:
    echo "Trying " & dir
    if fileExists(dir&"/nim-ci.sh"):
      nimcish = dir&"/nim-ci.sh"
      break

  if nimcish == "":
    echo "Couldn't find nim-ci.sh"
    return false

  # run all_the_things for each project
  for pkg in ["nimcibinary", "nimcihybrid", "nimcilibrary"]:
    withDir pkg:
      putEnv("NIM_PROJECT_DIR", ".")
      echo "PATH IS " & getEnv("PATH")
      exec "bash -c \"find /home/runner/.choosenim/bin\""
      exec "bash -c \"find /home/runner/.nimble/bin\""
      exec "bash -c \"find /home/runner/.choosenim/toolchains/nim-#devel/bin/\""
      /home/runner/.choosenim/toolchains/nim-#devel/bin/
      exec "bash -c \"source " & nimcish & "; all_the_things\""

task clean, "Removes all bin and dist directories":
  for pkg in [".", "nimcibinary", "nimcihybrid", "nimcilibrary"]:
    withDir pkg:
      rmDir("bin")
      rmDir("dist")

task test, "Runs the test suite":
  withDir "src":
    exec "nim c -r nimcitester.nim"
