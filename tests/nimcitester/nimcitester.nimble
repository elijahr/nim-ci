
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

  let home = getEnv("HOME")
  # run all_the_things for each project
  for pkg in ["nimcibinary", "nimcihybrid", "nimcilibrary"]:
    withDir pkg:
      putEnv("NIM_PROJECT_DIR", ".")
      echo "PATH IS " & getEnv("PATH")
      try:
        exec "bash -c \"find "&home&"/.choosenim/bin\""
      except:
        discard
      try:
        exec "bash -c \"find "&home&"/.nimble/bin\""
      except:
        discard
      try:
        exec "bash -c \"find "&home&"/.choosenim/toolchains/nim-#devel/bin/\""
      except:
        discard
      exec "bash -c \"source " & nimcish & "; all_the_things\""

task clean, "Removes all bin and artifacts directories":
  for pkg in [".", "nimcibinary", "nimcihybrid", "nimcilibrary"]:
    withDir pkg:
      rmDir("bin")
      rmDir("artifacts")

task test, "Runs the test suite":
  withDir "src":
    exec "nim c -r nimcitester.nim"
