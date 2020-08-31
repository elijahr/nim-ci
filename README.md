![GitHub Actions](https://github.com/elijahr/nim-ci/workflows/Build/badge.svg)
![Travis](https://travis-ci.org/elijahr/nim-ci.svg?branch=devel&status=errored)

## nim-ci

*Hassle-free continuous integration for Nim projects.*

### Supported platforms

* GitHub Actions
  * Linux (`amd64`, `arm64`, `powerpc64el`)
  * macOs (`amd64`)
  * Windows (`amd64`)

* Travis-CI
  * Linux (`amd64`, `arm64`, `powerpc64el`)
  * macOs (`amd64`)
  * Windows (`amd64`)

Pull requests with configuration files for other CIs are welcome.

This script is used by various tools like [nimble](https://github.com/nim-lang/nimble),
[choosenim](https://github.com/dom96/choosenim), and
[nimterop](https://github.com/nimterop/nimterop).

## Installation

### GitHub Actions

```sh
cd path/to/my/repo
curl -LsSf https://raw.githubusercontent.com/elijahr/nim-ci/v0.1.0/install_github.sh | sh
git add .github
git commit -m "Add GitHub Actions"
git push
```

### Travis-CI

```sh
cd path/to/my/repo
curl -LsSf https://raw.githubusercontent.com/elijahr/nim-ci/v0.1.0/install_travis.sh | sh
git add .travis.yml
git commit -m "Add Travis CI"
git push
```

### Other CIs

The [.travis.yml](https://github.com/elijahr/nim-ci/blob/v0.1.0/.travis.yml) config is an easy to read example. Essentially:

1. Install Nim

  ```sh
  curl https://raw.githubusercontent.com/elijahr/nim-ci/v0.1.0/nim-ci.sh -LsSf > nim-ci.sh
  source nim-ci.sh
  install_nim
  ```

2. Run your tests

  ```sh
  build_nim_project
  cd "$NIM_PROJECT_DIR"
  nimble test
  ```

3. If your project produces executables, generate artifacts:

  ```sh
  export_bin_artifacts
  # Do something with the artifact now at $ZIP_PATH
  ```

## Configuration

For most projects `nim-ci.sh` shouldn't need any configuration; just install it, enable GitHub Actions/Travis for your repo, and start pushing. Some configuration is possible through environment variables. See below.

### Environment variables

These environment variables can be customized in your GitHub/Travis config. If using another CI, set  these values prior to running `source nim-ci.sh`:

* `NIM_VERSION` - The version of Nim to install and build the project with. One of `devel`, `stable`, or specific release tags such as `0.16.0` or `v1.2.6`. Default: `stable`.

* `NIM_PROJECT_DIR` - The path to the Nim project, relative to the repository. Default: the first directory found containing a nimble file (usually this will be the repository itself).

* `OS_NAME` - The operating system being targeted, used when releasing zipfiles/tarballs. One of `linux`, `macosx`, or `windows`. Analagous values such as `ubuntu`, `osx`, and `mingw` will be normalized to correspond to Nim's [`hostOS`](https://nim-lang.org/docs/system.html#hostOS). Default: a value determined from `uname`.

* `CPU_ARCH` - The CPU architecture being targeted, used when releasing zipfiles/tarballs. One of `amd64`, `arm64`, or `powerpc64el`. Analagous values such as `x86_64`, `aarch64`, and `ppc64le` will be normalized to correspond to Nim's [`hostCPU`](https://nim-lang.org/docs/system.html#hostCPU). Default: a value determined from `uname -m`.

* `USE_CHOOSENIM` - If set to `yes`, Nim will be installed using [choosenim](https://github.com/dom96/choosenim). If set to `no`, Nim will be installed either via a nightly binary (when `NIM_VERSION` is `devel`) or built and installed from source (when `NIM_VERSION` is not `devel`). Default: `yes` when `CPU_ARCH` is `amd64`, `no` otherwise.

After running `source nim-ci.sh`, the above variables will be set, containing either your values (normalized) or the defaults. If you need to configure beyond setting these variables, you can of course edit the `build.yml` or `.travis.yml` files in your repo to suit your needs. Please do submit pull requests for improvements!

In addition to the above configurable variables, `nim-ci.sh` exports the following read-only environment variables.

* `BINS` - a bash array containing the `bin` entries from the nimble file.

* `BIN_DIR` - `binDir` value from the nimble file.

* `BIN_EXT` - `.exe` on Windows, empty otherwise.

* `DIST_DIR` - The interpolated value of `${NIM_PROJECT_PATH}/dist/${NIM_PROJECT_NAME}-${NIM_PROJECT_VERSION}-${OS_NAME}_${CPU_ARCH}`.

* `NIM_PROJECT_NAME` - The name of the Nim project.

* `NIM_PROJECT_TYPE` - `library` or `executables`, depending on whether the nimble file contains `bins`.

* `NIM_PROJECT_VERSION` - The version of the Nim project.

* `ZIP_EXT` - `.zip` on Windows, `.tar.xz` otherwise.

* `ZIP_NAME` - The interpolated value of `${NIM_PROJECT_NAME}-${NIM_PROJECT_VERSION}-${OS_NAME}_${CPU_ARCH}${ZIP_EXT}`.

* `ZIP_PATH` - The interpolated value of `${NIM_PROJECT_PATH}/dist/${NIM_PROJECT_NAME}-${NIM_PROJECT_VERSION}-${OS_NAME}_${CPU_ARCH}${ZIP_EXT}`.

### Bash functions

`nim-ci.sh` exports some bash functions:

* `add_path` - Add an entry to `PATH` in a cross-CI-platform way. For instance, GitHub Actions requires an additional step beyond simply setting `export PATH=foo:$PATH`.

* `build_nim_project` - If `NIM_PROJECT_TYPE` is `executables`, this will run `nimble install -y`. If `NIM_PROJECT_TYPE` is `library`, this will run `nimble develop -y`.

* `export_bin_artifacts` - If `NIM_PROJECT_TYPE` is `executables`, this will place the project's binaries in `DIST_DIR` and create the tarball/zipfile containing those binaries at `ZIP_PATH`. If `NIM_PROJECT_TYPE` is `library`, this is a no-op.

* `install_nim` - Install Nim and place it in `PATH`. This will use [choosenim](https://github.com/dom96/choosenim) when available for the architecture, otherwise will build Nim from source or use a nightly build, depending on the requested `NIM_VERSION`.
