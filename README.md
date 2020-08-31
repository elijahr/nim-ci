![GitHub Actions](https://github.com/elijahr/nim-ci/workflows/Build/badge.svg)
![Travis](https://travis-ci.org/elijahr/nim-ci.svg?branch=devel&status=errored)

## nim-ci

*Hassle-free continuous integration for Nim projects.*

Supported platforms:

* GitHub Actions
  * Linux (`amd64`, `arm64`, `powerpc64el`)
  * macOs (`amd64`)
  * Windows (`amd64`)

* Travis-CI
  * Linux (`amd64`, `arm64`, `powerpc64el`)
  * macOs (`amd64`)
  * Windows (`amd64`)

### Installing GitHub Actions

```sh
cd path/to/my/repo
curl -LsSf https://raw.githubusercontent.com/elijahr/nim-ci/devel/install_github.sh | sh
git add .github
git commit -m "Add GitHub Actions"
git push
```

### Installing Travis-CI

```sh
cd path/to/my/repo
curl -LsSf https://raw.githubusercontent.com/elijahr/nim-ci/devel/install_travis.sh | sh
git add .travis.yml
git commit -m "Add Travis CI"
git push
```

### Configuration

`nim-ci.sh` is configured through the following environment variables. The variables have sane defaults and setting them is optional. After running `source nim-ci.sh`, the variables will be set, containing either the (normalized) customized values or the default values.

* `OS_NAME` - The operating system being targeted, used when generating release filenames. One of `linux`, `macosx`, or `windows`. Default: a normalized value determined from `uname`.
* `CPU_ARCH` - The CPU architecture being targeted, used when generating release filenames. One of `amd64`, `arm64`, or `powerpc64el`. Default: a normalized value determined from `uname -m`.
* `NIM_VERSION` - The version of Nim to install and run the project's tests with. Values like `devel` or `stable` work, as will specific release tags, such as `0.16.0` or `v1.2.6`. Default: `stable`
* `NIM_PROJECT_DIR` - The path to the Nim project, relative to the repository. Default: The repository itself, or the first directory found containing a nimble file.
* `USE_CHOOSENIM` - If set to `yes`, Nim will be installed using [choosenim](https://github.com/dom96/choosenim). If set to `no`, Nim will be installed either via a nightly binary (when `NIM_VERSION` is `devel`) or built and installed from source (when `NIM_VERSION` is not `devel`). Default: `yes` when `CPU_ARCH` is `amd64`, `no` otherwise.

In addition to the configurable variables, `nim-ci.sh` exports some additional environment variables:

* `NIM_PROJECT_NAME` - The name of the Nim project
* `NIM_PROJECT_VERSION` - The version of the Nim project
* `NIM_PROJECT_TYPE` - `library` or `executables`, depending on whether the nimble file contains `bins`.
* `BINS` - a bash array containing the `bin` entries from the nimble file.
* `BIN_DIR` - `binDir` value from the nimble file.
* `BIN_EXT` - `.exe` on Windows, empty otherwise.
* `ZIP_EXT` - `.zip` on Windows, `.tar.xz` otherwise.
* `DIST_DIR` - The interpolated value of `${NIM_PROJECT_PATH}/dist/${NIM_PROJECT_NAME}-${NIM_PROJECT_VERSION}-${OS_NAME}_${CPU_ARCH}`.
* `ZIP_PATH` - The interpolated value of `${NIM_PROJECT_PATH}/dist/${NIM_PROJECT_NAME}-${NIM_PROJECT_VERSION}-${OS_NAME}_${CPU_ARCH}${ZIP_EXT}`.
* `ZIP_NAME` - The interpolated value of `${NIM_PROJECT_NAME}-${NIM_PROJECT_VERSION}-${OS_NAME}_${CPU_ARCH}${ZIP_EXT}`.

`nim-ci.sh` exports some bash functions:

* `install_nim` - Install Nim and place it in the `PATH`. This will use [choosenim](https://github.com/dom96/choosenim) if available for the architecture, otherwise will build Nim from source or use a nightly build, depending on the requested `NIM_VERSION`.
* `build_nim_project` - If `NIM_PROJECT_TYPE` is `executables`, this will run `nimble install -y`. If `NIM_PROJECT_TYPE` is `library`, this will run `nimble develop -y`.
* `export_bin_artifacts` - If `NIM_PROJECT_TYPE` is `executables`, this will place the project's binaries in `DIST_DIR` and create the tarball/zipfile containing those binaries at `ZIP_PATH`. If `NIM_PROJECT_TYPE` is `library`, this is a no-op.
* `add_path` - Add an entry to `PATH` in a cross-platform way; GitHub Actions requires an additional step beyond simply setting `export PATH=foo:$PATH`.

`nim-ci.sh` supports Travis CI and GitHub Actions, but can likely be used on most CI environments. Pull requests to support other CI environments are welcome.

This script is used by various tools like [nimble](https://github.com/nim-lang/nimble),
[choosenim](https://github.com/dom96/choosenim), and
[nimterop](https://github.com/nimterop/nimterop).

