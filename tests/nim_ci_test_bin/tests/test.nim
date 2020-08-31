import os
import osproc
import strutils
import system
import unittest

const zipExt =
  when defined(windows): ".zip"
  else: ".tar.xz"

proc distName(): string = "nim_ci_test_bin-0.1.0-" & hostOS & "_" & hostCPU
proc distDir(): string = (".."/"dist"/distName()).absolutePath
proc binDir(): string = (".."/"bin").absolutePath


suite "test":
  test "executables were built by nimble build":
    for bin in ["nim_ci_test_bin_1", "nim_ci_test_bin_2"]:
      let (output, exitCode) = execCmdEx(binDir()/bin)
      check exitCode == 0
      check output.strip == bin

  test "executables were built and placed in dist directory by make_artifact":
    for bin in ["nim_ci_test_bin_1", "nim_ci_test_bin_2"]:
      let (output, exitCode) = execCmdEx(distDir()/bin)
      check exitCode == 0
      check output.strip == bin

  test "executables were installed in PATH by nimble install":
    for bin in ["nim_ci_test_bin_1", "nim_ci_test_bin_2"]:
      let (output, exitCode) = execCmdEx("which " & bin)
      check exitCode == 0
      check output.strip notin [
        "",
        distDir()/bin,
        binDir()/bin,
      ]
    for bin in ["nim_ci_test_bin_1", "nim_ci_test_bin_2"]:
      let (output, exitCode) = execCmdEx(bin)
      check exitCode == 0
      check output.strip == bin

  test "zip is sane":
    let zipFile = distDir() & zipExt
    let outDir = getTempDir()/"nim_ci_test_bin"
    removeDir(outDir)
    createDir(outDir)
    let (output, exitCode) = execCmdEx("tar xf " & zipFile & " -C " & outDir)
    defer:
      removeDir(outDir)
    check exitCode == 0
    check output.strip == ""
    check dirExists(outDir/distName())
    for bin in ["nim_ci_test_bin_1", "nim_ci_test_bin_2"]:
      let (output, exitCode) = execCmdEx(outDir/distName()/bin)
      check exitCode == 0
      check output.strip == bin
