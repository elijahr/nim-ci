![GitHub Actions](https://github.com/elijahr/nim-ci/workflows/Build/badge.svg)
![Travis](https://travis-ci.org/elijahr/nim-ci.svg?branch=devel&status=errored)

## nim-ci

*Hassle-free continuous integration for Nim projects.*

### Supported platforms

* GitHub Actions
  * Linux (`amd64`, `arm64`, `powerpc64el`)
  * macOS (`amd64`)
  * Windows (`amd64`)

* Travis CI
  * Linux (`amd64`, `arm64`, `powerpc64el`)
  * macOS (`amd64`)
  * Windows (`amd64`)

This script is used by various tools like [nimble](https://github.com/nim-lang/nimble),
[choosenim](https://github.com/dom96/choosenim), and
[nimterop](https://github.com/nimterop/nimterop).

## Installation

### GitHub Actions

Run this in your repository:

```sh
curl -LsSf https://raw.githubusercontent.com/elijahr/nim-ci/devel/install_github.sh | sh
git add .github
git commit -m "Add GitHub Actions"
git push
```

### Travis CI

Run this in your repository:

```sh
curl -LsSf https://raw.githubusercontent.com/elijahr/nim-ci/devel/install_travis.sh | sh
git add .travis.yml
git commit -m "Add Travis CI"
git push
```

### Other CIs

The `nim-ci.sh` script should work with any CI that can run bash scripts.
Pull requests with configuration files for other CIs are welcome. The [.travis.yml](https://github.com/elijahr/nim-ci/blob/devel/.travis.yml) config is an easy to read example to follow. Essentially:

1. Install Nim.

  ```sh
  set -e
  curl https://raw.githubusercontent.com/elijahr/nim-ci/devel/nim-ci.sh -LsSf > nim-ci.sh
  source nim-ci.sh
  ```

2. Build project and run tests.

  ```sh
  install_nim_project
  cd "$NIM_PROJECT_DIR"
  nimble test
  ```

3. If the project produces binaries, `make_zipball` will package them as a zipball.

  ```sh
  make_zipball
  # Do something with the zipball now at $ZIP_PATH
  ```

## Configuration

For most projects `nim-ci.sh` shouldn't need any configuration; just install it, enable GitHub Actions/Travis CI for your repo, and start pushing. CI will build the project and run the test suite for any branch or pull request, using the following matrix:

* Platforms: `linux_amd64`, `macosx_amd64`, `windows_amd64`, `linux_arm64`, `linux_powerpc64el`
* Nim: `0.20.2`, `1.0.8`, `1.2.6`, `devel`

If your project produces binaries (`NIM_PROJECT_TYPE` of `hybrid` or `binary`), pushing a git tag will cause `nim-ci` to create and upload zipballs to GitHub for `linux_amd64`, `macosx_amd64`, `windows_amd64`, `linux_arm64`, and `linux_powerpc64el`. Some configuration is possible through environment variables, see below:

### Configurable environment variables

These environment variables can be set in your GitHub/Travis config and will be used by `nim-ci.sh`. If using another CI, set these values prior to running `source nim-ci.sh`:

#### `NIM_CI_VERSION`

The version of `nim-ci.sh` to use. Defaults to `devel`. If the requested version of `nim-ci.sh` is not the currently installed version of `nim-ci.sh`, the requested version will be fetched and sourced instead of the installed version.

#### `NIM_VERSION`

The version of Nim to install and build the project with. One of `devel`, `stable`, or specific release tags such as `0.16.0` or `v1.2.6`. Default: `stable`.

#### `NIM_PROJECT_DIR`

The path to the Nim project. Paths relative to the current working directory will be normalized into an absolute path. For example, if the working directory is `/home/travis`, a `NIM_PROJECT_DIR` of `foo` would become `/home/travis/foo` after running `source nim-ci.sh`. Default: the lowest directory in the working directory found containing a .nimble file, up to and including the working directory itself; for example, if both `/home/travis/foo/foo.nimble` and `/home/travis/extras/bar/bar.nimble` exist, `NIM_PROJECT_DIR` will default to `/home/travis/foo` because it is lower in the directory tree.

#### `USE_CHOOSENIM`

If set to `yes`, Nim will be installed using [choosenim](https://github.com/dom96/choosenim). If set to `no`, Nim will be installed either via a nightly binary (when `NIM_VERSION` is `devel`) or built and installed from source. Default: `yes` when `HOST_CPU` is `amd64`, `no` otherwise.

After `source nim-ci.sh` completes, Nim will be installed and the above variables will be set. If you need to customize the build beyond setting these variables, such as adding or removing target architectures from the build matrix, you can of course edit the `build.yml` or `.travis.yml` files installed in your repo to suit your needs. `nim-ci` also exports some [bash functions](#Functions) that you may find useful for customizing the build steps. If you make any changes that others would find useful, please do submit a pull request.

### Exported environment variables

In addition to the above configurable variables, `nim-ci.sh` exports the following environment variables.

#### `BINS`

A bash array containing the `bin` entries from the .nimble file.

#### `BIN_DIR`

The `binDir` value from the .nimble file.

#### `BIN_EXT`

`.exe` on Windows, empty otherwise.

#### `DIST_DIR`

The interpolated value of `${NIM_PROJECT_DIR}/dist/${NIM_PROJECT_NAME}-${NIM_PROJECT_VERSION}-${HOST_OS}_${HOST_CPU}`, for example `/home/travis/foo/dist/foo-0.1.0-linux_arm64`. Any files placed in this directory will be included in the zipball produced by `make_zipball`.

#### `HOST_CPU`

The current CPU architecture, corresponding to Nim's [`hostCPU`](https://nim-lang.org/docs/system.html#hostCPU).

#### `HOST_OS`

The current OS, corresponding to Nim's [`hostOS`](https://nim-lang.org/docs/system.html#hostOS).

#### `NIM_PROJECT_NAME`

The name of the Nim project. For example, given a project containing a `foo.nimble` file, `NIM_PROJECT_NAME` will be `foo`.

#### `NIM_PROJECT_TYPE`

[`library`](https://github.com/nim-lang/nimble#libraries), [`binary`](https://github.com/nim-lang/nimble#binary-packages), or [`hybrid`](https://github.com/nim-lang/nimble#hybrids).

#### `NIM_PROJECT_VERSION`

The `version` value from the .nimble file.

#### `SRC_DIR`

The `srcDir` value from the .nimble file.

#### `ZIP_EXT`

`.zip` on Windows, `.tar.xz` otherwise.

#### `ZIP_PATH`

The absolute path to the zipball created by calling `make_zipball`. This will be the interpolated value of `${NIM_PROJECT_DIR}/dist/${NIM_PROJECT_NAME}-${NIM_PROJECT_VERSION}-${HOST_OS}_${HOST_CPU}${ZIP_EXT}`, for example `/home/travis/foo/dist/foo-0.1.0-linux_arm64.tar.xz`.

### Functions

`nim-ci.sh` exports some bash functions:

#### `add_path <path>`

Add an entry to `PATH` in a cross-CI-platform way. For instance, GitHub Actions requires an additional step beyond simply setting `export PATH=foo:$PATH`.

#### `install_nim_project`

 If `NIM_PROJECT_TYPE` is `binary` or `hybrid`, this will run `nimble install -y`. If `NIM_PROJECT_TYPE` is `library`, this will run `nimble develop -y`.

#### `installed_nim_version`

Echoes the first version of Nim found in `PATH`.

#### `make_zipball`

If `NIM_PROJECT_TYPE` is `binary` or `hybrid`, this will copy the project's binaries to `DIST_DIR` and create a zipball from `DIST_DIR` at `ZIP_PATH`. If `NIM_PROJECT_DIR` contains `README*`, `LICENSE*`, `AUTHORS*`, `COPYING*`, `*.txt` or `*.md` files, those will also be included in the zipball. If `NIM_PROJECT_TYPE` is `library`, `make_zipball` is a no-op, unless you have explicitly placed items in `DIST_DIR`, in which case a zipball is created. If the project has not been built yet, `make_zipball` will call `install_nim_project` first to build your project's binaries.

#### `normalize_to_host_cpu <cpu>`

Echose the normalization of string `<cpu>` such as `aarch64`, `x86_64`, or `ppc64le` to its corresponding value from Nim's [`system.hostCPU`](https://nim-lang.org/docs/system.html#hostCPU).

#### `normalize_to_host_os <os>`

Echoes the normalization of string `<os>` such as `Ubuntu`, `mingw`, or `osx` to its corresponding value from Nim's [`system.hostOS`](https://nim-lang.org/docs/system.html#hostOS).

#### `stable_nim_version`

Fetches and echoes the current stable version tag of Nim. No return code.

___

Happy hacking!
