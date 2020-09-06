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

proc projectDir(pkg: string): string =
  result =
    if pkg == "nimcitester": "..".absolutePath
    else: (".."/pkg).absolutePath

proc projectType(pkg: string): string =
  result =
    if pkg == "nimcihybrid": "hybrid"
    elif pkg == "nimcilibrary": "library"
    else: "binary"

proc artifactsDir(pkg: string): string = projectDir(pkg)/"artifacts"

proc binDir(pkg: string): string =
  if projectType(pkg) in ["binary", "hybrid"]: projectDir(pkg)/"bin"
  else: ""

proc binArtifact(pkg: string, bin: string): string =
  artifactsDir(pkg)/bin & "-0.1.0-" & hostOS & "_" & hostCPU

const useChoosenim =
  when hostCPU == "amd64": "yes"
  else: "no"

proc exec(
  command: string,
  options: set[ProcessOption] = {
    poStdErrToStdOut, poUsePath
  },
  env: StringTableRef = nil,
  liveOutput: bool = true
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
      if liveOutput:
        echo line
      result[0].string.add(line.string)
      result[0].string.add("\n")
    else:
      result[1] = peekExitCode(p)
      if result[1] != -1: break
  close(p)


const config = """

$1ARTIFACTS_DIR::$2
$1BIN_DIR::$3
$1BIN_EXT::$4
$1HOST_CPU::$5
$1HOST_OS::$6
$1NIM_PROJECT_DIR::$7
$1NIM_PROJECT_NAME::$8
$1NIM_PROJECT_TYPE::$9
$1NIM_VERSION::$10
$1SRC_DIR::src
$1USE_CHOOSENIM::$11

""".strip


suite "nim-ci.sh init":
  test "infers defaults":
    let pkg = "nimcitester"
    let (output, exitCode) = exec(nimci())
    check exitCode == 0
    let expected = config % [
      "", artifactsDir(pkg), binDir(pkg), binExt, hostCPU, hostOS,
      projectDir(pkg), pkg, projectType(pkg), "stable", useChoosenim
    ]
    check expected in output

  test "sets GitHub Action step outputs":
    let pkg = "nimcitester"
    let env = newStringTable({
      "PATH": getEnv("PATH"),
      "HOME": getEnv("HOME"),
      "GITHUB_WORKFLOW": "foo",
    })
    let (output, exitCode) = exec(nimci(), env=env)
    check exitCode == 0
    let expected = config % [
      "::set-output name=", artifactsDir(pkg), binDir(pkg), binExt,
      hostCPU, hostOS, projectDir(pkg), pkg, projectType(pkg), "stable",
      useChoosenim,
    ]
    check expected in output

  test "is configurable":
    for pkg in ["nimcibinary", "nimcihybrid", "nimcilibrary"]:
      let env = newStringTable({
        "PATH": getEnv("PATH"),
        "HOME": getEnv("HOME"),
        "NIM_PROJECT_DIR": projectDir(pkg),
        "NIM_VERSION": "devel",
        "USE_CHOOSENIM": "no",
      })
      let (output, exitCode) = exec(nimci(), env=env)
      check exitCode == 0
      let expected = config % [
        "", artifactsDir(pkg), binDir(pkg), binExt, hostCPU, hostOS,
        projectDir(pkg), pkg, projectType(pkg), "devel", "no",
      ]
      check expected in output

suite "binary/hybrid":
  test "binaries were built by nimble build":
    for pkg in ["nimcibinary", "nimcihybrid"]:
      for i in 1..2:
        let (output, exitCode) = exec(binDir(pkg)/pkg & $i)
        check exitCode == 0
        check output.strip == pkg & $i

  test "binaries were built and placed in artifacts directory by make_bin_artifacts":
    for pkg in ["nimcibinary", "nimcihybrid"]:
      for i in 1..2:
        let (output, exitCode) = exec(binArtifact(pkg, pkg & $i))
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

  # test "zipball is sane":
  #   for pkg in ["nimcibinary", "nimcihybrid"]:
  #     let outDir = getTempDir()/pkg
  #     removeDir(outDir)
  #     createDir(outDir)
  #     let (output, exitCode) =
  #       when defined(windows): exec("unzip -q " & zipPath(pkg) & " -d " & outDir)
  #       else: exec("tar xf " & zipPath(pkg) & " -C " & outDir)
  #     defer:
  #       removeDir(outDir)
  #     check exitCode == 0
  #     check output.strip == ""
  #     check dirExists(outDir)
  #     check fileExists(outDir/"AUTHORS")
  #     check fileExists(outDir/"COPYING")
  #     check fileExists(outDir/"LICENSE")
  #     check fileExists(outDir/"README")
  #     check fileExists(outDir/"foo.txt")
  #     check fileExists(outDir/"bar.md")
  #     for i in 1..2:
  #       let (output, exitCode) = exec(outDir/pkg & $i)
  #       check exitCode == 0
  #       check output.strip == pkg & $i

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
