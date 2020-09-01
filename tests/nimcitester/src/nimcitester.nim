import os
import osproc
import streams
import strtabs
import strutils
import system
import unittest

const zipExt =
  when defined(windows): ".zip"
  else: ".tar.xz"

const binExt =
  when defined(windows): ".exe"
  else: ""

proc repoDir(): string = (".."/".."/"..").absolutePath

proc nimci(): string = "bash -c 'source " & repoDir()/"nim-ci.sh'"

proc distName(pkg: string): string = pkg & "-0.1.0-" & hostOS & "_" & hostCPU

proc projectDir(pkg: string): string =
  result =
    if pkg == "nimcitester": "..".absolutePath
    else: (".."/pkg).absolutePath

proc projectType(pkg: string): string =
  result =
    if pkg == "nimcihybrid": "hybrid"
    elif pkg == "nimcilibrary": "library"
    else: "binary"

proc distDir(pkg: string): string = projectDir(pkg)/"dist"/distName(pkg)

proc binDir(pkg: string): string =
  if projectType(pkg) in ["binary", "hybrid"]: projectDir(pkg)/"bin"
  else: ""

proc bins(pkg: string): string =
  result =
    if pkg == "nimcihybrid": "nimcihybrid1, nimcihybrid2"
    elif pkg == "nimcibinary": "nimcibinary1, nimcibinary2"
    elif pkg == "nimcilibrary": ""
    else: "nimcitester"

proc zipName(pkg: string): string = distName(pkg) & zipExt

proc zipPath(pkg: string): string = projectDir(pkg)/"dist"/zipName(pkg)


const useChoosenim =
  when hostCPU == "amd64": "yes"
  else: "no"

proc exec(
  command: string,
  options: set[ProcessOption] = {
    poStdErrToStdOut, poUsePath
  },
  env: StringTableRef = nil,
): tuple[
  output: TaintedString,
  exitCode: int
] {.
  tags:[ExecIOEffect, ReadIOEffect, RootEffect],
  gcsafe
.} =
  var p = startProcess(command, options = options + {poEvalCommand},
    workingDir = repoDir(), env = env)
  var outp = outputStream(p)

  result = (TaintedString"", -1)
  var line = newStringOfCap(120).TaintedString
  while true:
    if outp.readLine(line):
      result[0].string.add(line.string)
      result[0].string.add("\n")
    else:
      result[1] = peekExitCode(p)
      if result[1] != -1: break
  close(p)


const config = """
>>> nim-ci config >>>

$1BINS::$2
$1BIN_DIR::$3
$1BIN_EXT::$4
$1DIST_DIR::$5
$1HOST_CPU::$6
$1HOST_OS::$7
$1NIM_PROJECT_DIR::$8
$1NIM_PROJECT_NAME::$9
$1NIM_PROJECT_TYPE::$10
$1NIM_VERSION::$11
$1SRC_DIR::src
$1USE_CHOOSENIM::$12
$1ZIP_EXT::$13
$1ZIP_NAME::$14
$1ZIP_PATH::$15

<<< nim-ci config <<<
""".strip


suite "nim-ci.sh init":
  test "infers defaults":
    let pkg = "nimcitester"
    let (output, exitCode) = exec(nimci())
    check exitCode == 0
    let expected = config % [
      "", bins(pkg), binDir(pkg), binExt, distDir(pkg), hostCPU, hostOS,
      projectDir(pkg), pkg, projectType(pkg), "stable", useChoosenim, zipExt,
      zipName(pkg), zipPath(pkg),
    ]
    check expected in output

  test "sets GitHub Action step outputs":
    let pkg = "nimcitester"
    let env = newStringTable({
      "HOME": getEnv("HOME"),
      "GITHUB_WORKFLOW": "foo",
    })
    let (output, exitCode) = exec(nimci(), env=env)
    check exitCode == 0
    let expected = config % [
      "::set-output name=", bins(pkg), binDir(pkg), binExt, distDir(pkg),
      hostCPU, hostOS, projectDir(pkg), pkg, projectType(pkg), "stable",
      useChoosenim, zipExt, zipName(pkg), zipPath(pkg),
    ]
    check expected in output

  test "is configurable":
    for pkg in ["nimcibinary", "nimcihybrid", "nimcilibrary"]:
      let env = newStringTable({
        "HOME": getEnv("HOME"),
        "NIM_PROJECT_DIR": projectDir(pkg),
        "NIM_VERSION": "devel",
        "USE_CHOOSENIM": "no",
      })
      let (output, exitCode) = exec(nimci(), env=env)
      check exitCode == 0
      let expected = config % [
        "", bins(pkg), binDir(pkg), binExt, distDir(pkg), hostCPU, hostOS,
        projectDir(pkg), pkg, projectType(pkg), "devel", "no", zipExt,
        zipName(pkg), zipPath(pkg),
      ]
      check expected in output

suite "binary/hybrid":
  test "binaries were built by nimble build":
    for pkg in ["nimcibinary", "nimcihybrid"]:
      for i in 1..2:
        let (output, exitCode) = exec(binDir(pkg)/pkg & $i)
        check exitCode == 0
        check output.strip == pkg & $i

  test "binaries were built and placed in dist directory by make_zipball":
    for pkg in ["nimcibinary", "nimcihybrid"]:
      for i in 1..2:
        let (output, exitCode) = exec(distDir(pkg)/pkg & $i)
        check exitCode == 0
        check output.strip == pkg & $i

  test "binaries were installed in PATH by nimble install":
    for pkg in ["nimcibinary", "nimcihybrid"]:
      for i in 1..2:
        block:
          let (output, exitCode) = exec("which " & pkg & $i)
          check exitCode == 0
          check output.strip == getEnv("HOME")/".nimble"/"bin"/pkg & $i
        block:
          let (output, exitCode) = exec(pkg & $i)
          check exitCode == 0
          check output.strip == pkg & $i

  test "zipball is sane":
    for pkg in ["nimcibinary", "nimcihybrid"]:
      let outDir = getTempDir()/pkg
      removeDir(outDir)
      createDir(outDir)
      let (output, exitCode) =
        when defined(windows): exec("unzip -q " & zipPath(pkg) & " -d " & outDir)
        else: exec("tar xf " & zipPath(pkg) & " -C " & outDir)
      defer:
        removeDir(outDir)
      check exitCode == 0
      check output.strip == ""
      check dirExists(outDir/distName(pkg))
      for i in 1..2:
        let (output, exitCode) = exec(outDir/distName(pkg)/pkg & $i)
        check exitCode == 0
        check output.strip == pkg & $i

suite "library/hybrid":
  test "library symlink was installed":
    let link = getEnv("HOME")/".nimble"/"pkgs"/"nimcilibrary-#head"/"nimcilibrary.nimble-link"
    check fileExists(link)
    check readFile(link).strip == (
      projectDir("nimcilibrary")/"nimcilibrary.nimble" & "\n" &
      projectDir("nimcilibrary")/"src"
    )

  test "hybrid *pkg was installed":
    let lib = getEnv("HOME")/".nimble"/"pkgs"/"nimcihybrid-0.1.0"/"nimcihybridpkg"/"nimcihybridpkg.nim"
    check fileExists(lib)
