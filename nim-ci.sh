#!/bin/bash

set -euo pipefail

# return codes
export RET_OK=0
export RET_ERROR=1

add_path () {
  # Add an entry to PATH
  export PATH="$1:$PATH"
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]
  then
    # GitHub Actions syntax for adding to path across steps
    echo "::add-path::$1"
  fi
}

normalize_to_host_cpu() {
  # Normalize a CPU architecture string to match Nim's system.hostCPU values.
  # The echo'd value is one of:
  # * i386
  # * amd64
  # * arm64
  # * arm
  # * ppc64le

  local CPU=$(echo $1 | tr "[:upper:]" "[:lower:]")

  case $CPU in
    *amd*64* | *x86*64* | x64 ) local CPU="amd64" ;;
    *x86* | *i*86* | x32 ) local CPU="i386" ;;
    *aarch64*|*arm64* ) local CPU="arm64" ;;
    *arm* ) local CPU="arm" ;;
    *ppc64le* | powerpc64el ) local CPU="powerpc64el" ;;
  esac

  echo $CPU
}

normalize_to_host_os () {
  # Normalize an OS name string to match Nim's system.hostOS values.
  # The echo'd value is one of:
  # * linux
  # * macosx
  # * windows

  local OS=$(echo $1 | tr "[:upper:]" "[:lower:]")

  case $OS in
    *linux* | *ubuntu* | *alpine* | *debian* | *jessie* | *buster* \
    | *stretch* | *arch* | *gentoo* | *fedora* | *manjaro* )
      local OS="linux" ;;
    *darwin* | *macos* | *osx* | *macosx* ) local OS="macosx" ;;
    *mingw* | *msys* | *windows* ) local OS="windows" ;;
  esac

  echo $OS
}

github_api_curl_args () {
  if [[ ! -z "${GITHUB_TOKEN:-}" ]]
  then
    # Set GITHUB_TOKEN env var to avoid rate-limiting
    echo "-H Authorization:\\ Bearer\\ ${GITHUB_TOKEN}"
  fi
}

download_nightly() {
  # Try to download a nightly Nim build from https://github.com/nim-lang/nightlies/releases
  # Returns 0 if download was succesful, 1 otherwise.
  if [[ "$HOST_OS" == "linux" ]]
  then
    if [[ "$HOST_CPU" == "amd64" ]]
    then
      local SUFFIX="linux_x64\.tar\.xz"
    else
      # linux_arm64, etc
      local SUFFIX="linux_${HOST_CPU}\.tar\.xz"
    fi
  elif [[ "$HOST_OS" == "macosx" ]]
  then
    if [[ "$HOST_CPU" == "amd64" ]]
    then
      # Used to be osx.tar.xz, now is macosx_x64.tar.xz
      local SUFFIX="macosx_x64\.tar\.xz"
    else
      # macosx_arm64, perhaps someday
      local SUFFIX="macosx_${HOST_CPU}\.tar\.xz"
    fi
  elif [[ "$HOST_OS" == "windows" ]]
  then
    local SUFFIX="windows_x64\.zip"
  fi

  if [[ ! -z "$SUFFIX" ]]
  then
    # Fetch nightly download url. This is subject to API rate limiting, so may fail
    # intermittently, in which case the script will fallback to building Nim.
    local NIGHTLY_API_URL="https://api.github.com/repos/nim-lang/nightlies/releases"
    local NIGHTLY_DOWNLOAD_URL=$(eval curl $NIGHTLY_API_URL $(github_api_curl_args) -LsSf \
      | grep "\"browser_download_url\": \".*${SUFFIX}\"" \
      | head -n 1 \
      | sed -n 's/".*\(https:.*\)".*/\1/p')
  fi

  if [[ ! -z "$NIGHTLY_DOWNLOAD_URL" ]]
  then
    local NIGHTLY_ARCHIVE="/tmp/$(basename $NIGHTLY_DOWNLOAD_URL)"
    curl $NIGHTLY_DOWNLOAD_URL -LsSf -o $NIGHTLY_ARCHIVE
  else
    echo "No nightly build available for $HOST_OS $HOST_CPU"
    local NIGHTLY_ARCHIVE=""
  fi

  local NIM_DIR="${CHOOSENIM_DIR}/toolchains/nim-#devel"
  if [[ ! -z "$NIGHTLY_ARCHIVE" && -f "$NIGHTLY_ARCHIVE" ]]
  then
    rm -Rf "$NIM_DIR"
    mkdir -p "$NIM_DIR"
    if [[ "$HOST_OS" == "windows" ]]
    then
      unzip -q "$NIGHTLY_ARCHIVE" -d "$NIM_DIR"
      local UNZIP_DIR=$(find "$NIM_DIR" -type d -name "nim-*" -print -quit \
        | head -n 1)
      echo "UNZIP_DIR=$UNZIP_DIR"
      echo "NIM_DIR=$NIM_DIR"
      if [[ ! -z "$UNZIP_DIR" ]]
      then
        mv "$UNZIP_DIR"/* "$NIM_DIR/"
      fi
    else
      tar -xf "$NIGHTLY_ARCHIVE" -C "$NIM_DIR" --strip-components=1
      mv "${NIM_DIR}/nim-"*/* "${NIM_DIR}/"
    fi
    rm "$NIGHTLY_ARCHIVE"

    if [[ -p "${NIM_DIR}/bin/nim" ]]
    then
      add_path "${NIM_DIR}/bin"
      echo "Installed nightly build $NIGHTLY_DOWNLOAD_URL"
      return $RET_OK
    else
      find "${NIM_DIR}" || echo "No such thing: $NIM_DIR"
      echo "Error installing Nim"
    fi
  fi

  return $RET_ERROR
}

stable_nim_version () {
  # Echoes the tag name of the current stable version of Nim
  if [[ -z "${NIM_STABLE_VERSION:-}" ]]
  then
    export NIM_STABLE_VERSION="$(git ls-remote https://github.com/nim-lang/Nim.git \
      | grep refs/tags/v \
      | tail -n 2 \
      | head -n 1 \
      | sed 's/^.*tags\/v//')"
  fi
  echo "$NIM_STABLE_VERSION"
}

installed_nim_version () {
  # Echoes the tag name of the installed version of Nim.
  # A path to a specific nim binary may be provided.
  local NIM=${1:-nim}
  if type -p "$NIM" &> /dev/null
  then
    "$NIM" -v | head -n 1 | sed -n 's/.*Version \([^ ]\{1,\}\).*/\1/p'
  fi
}

nim_version_to_git_ref () {
  local VERSION="${1:-${NIM_VERSION}}"
  if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  then
    # Semantic version tag
    echo "v${VERSION}"
  else
    if [[ "$VERSION" == "stable" ]]
    then
      stable_nim_version
    else
      # branch name or commit hash
      echo "$VERSION"
    fi
  fi
}

install_nim_nightly_or_build_nim () {
  # Build Nim from source, sans choosenim

  # Not actually using choosenim, but cache in same location.
  if [[ "$NIM_VERSION" == "devel" ]]
  then
    # Try downloading nightly build
    download_nightly
    if [[ "$?" == "$RET_OK" ]]
    then
      # Nightly build was downloaded
      return $RET_OK
    fi
    local TOOLCHAIN_ID="#devel"
  else
    if [[ "$NIM_VERSION" == "stable" ]]
    then
      TOOLCHAIN_ID=$(stable_nim_version)
    else
      TOOLCHAIN_ID="$NIM_VERSION"
    fi
    if [[ "$TOOLCHAIN_ID" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
    then
      # Strip leading v for tags
      TOOLCHAIN_ID=$(cat "$TOOLCHAIN_ID" | sed -n 's/^v//p')
    fi
  fi

  local NIM_DIR="${CHOOSENIM_DIR}/toolchains/nim-${TOOLCHAIN_ID}-${HOST_CPU}"
  mkdir -p "$NIM_DIR"

  add_path "${NIM_DIR}/bin"
  if type -p "${NIM_DIR}/bin/nim" &> /dev/null
  then
    # TODO - pull/rebuild devel?
    echo "Using cached Nim ${NIM_DIR}/bin/nim"
    return $RET_OK
  fi

  local GITREF=$(nim_version_to_git_ref "$TOOLCHAIN_ID")
  echo "Building Nim $GITREF"
  cd $NIM_DIR
  local TARBALL_URL="https://api.github.com/repos/nim-lang/Nim/tarball/${GITREF}"
  eval curl "$TARBALL_URL" $(github_api_curl_args) -LsSf -o Nim.tar.gz
  tar -xzf Nim.tar.gz
  rm Nim.tar.gz
  mv nim-lang-Nim-*/* . >/dev/null 2>&1 || true
  mv nim-lang-Nim-*/.[a-z]* . >/dev/null 2>&1 || true
  sh build_all.sh
  cd - &>/dev/null
  return $RET_OK
}

install_windows_git () {
  # Install Git for Windows
  cd "${NIM_CI_CACHE}"
  curl https://github.com/git-for-windows/git/releases/download/v2.23.0.windows.1/PortableGit-2.23.0-64-bit.7z.exe \
    -LsSf -o portablegit.exe
  7z x -y -bd portablegit.exe
  cd - &>/dev/null
}

install_nim_with_choosenim () {
  mkdir -p "${CHOOSENIM_DIR}"
  mkdir -p "${NIMBLE_DIR}"
  add_path "${NIMBLE_DIR}/bin"
  add_path "${CHOOSENIM_DIR}/bin"


  if [[ "$HOST_OS" == "windows" ]]
  then
    # on windows, install nim then build choosenim, for debugging choosenim extract error
    install_windows_git
    download_nightly
    local TARBALL_URL="https://api.github.com/repos/elijahr/choosenim/tarball/dll-extract-fix"
    eval curl "$TARBALL_URL" $(github_api_curl_args) -LsSf -o choosenim.tar.gz
    tar -xzf choosenim.tar.gz
    rm choosenim.tar.gz
    cd elijahr-choosenim-*
    nimble install
    cd -
  else
    # Install a Nim binary or build Nim from source, using choosenim
    if ! type -p "${NIMBLE_DIR}/bin/choosenim" &> /dev/null
    then
      echo "Installing choosenim"
      if [[ "$HOST_OS" == "windows" ]]
      then
        install_windows_git
      fi

      # curl https://nim-lang.org/choosenim/init.sh -sSf -o choosenim-init.sh
      if [[ ! -f "${NIM_CI_CACHE}/choosenim-init.sh" ]]
      then
        curl https://raw.githubusercontent.com/elijahr/nim-ci/github-workflows/choosenim-init.sh \
          -LsSf -o "${NIM_CI_CACHE}/choosenim-init.sh"
      fi
      sh "${NIM_CI_CACHE}/choosenim-init.sh" -y

      if [[ "$HOST_OS" == "windows" ]]
      then
        # Workaround for error in choosenim on GitHub Actions windows-latest:
        # 'Unable to extract. Error was 'Cannot create a file when that file already exists.'
        # We pre-fetch the DLLs and add them to PATH so choosenim doesn't try to
        # fetch and extract.
        if [[ ! -f "${NIM_CI_CACHE}/dlls.zip" ]]
        then
          curl http://nim-lang.org/download/dlls.zip -LsSf -o "${NIM_CI_CACHE}/dlls.zip"
        fi

        # Workaround for error in choosenim on GitHub Actions windows-latest:
        # 'Unable to extract. Error was 'Cannot create a file when that file already exists.'
        # We pre-fetch the DLLs and add them to PATH so choosenim doesn't try to
        # fetch and extract.
        rm -rf "${CHOOSENIM_DIR}/downloads"

        # FYI - ${NIM_CI_CACHE}/bin is already in PATH
        unzip -q "${NIM_CI_CACHE}/dlls.zip" -d "${NIM_CI_CACHE}/bin" || true
      fi
      echo "Installed choosenim"
    else
      echo "choosenim already installed"
    fi
  fi

  if [[ ! -f "${NIMBLE_DIR}/bin/choosenim" && \
        "${NIMBLE_DIR}" != "${HOME}/.nimble" ]]
  then
    # If a custom NIMBLE_DIR was provided choosenim won't have installed there,
    # so update PATH to include choosenim.
    add_path "${HOME}/.nimble/bin"
  fi

  # Workaround for error in choosenim on GitHub Actions windows-latest:
  # 'Unable to extract. Error was 'Cannot create a file when that file already exists.'
  # We pre-fetch the DLLs and add them to PATH so choosenim doesn't try to
  # fetch and extract.
  rm -rf "${CHOOSENIM_DIR}/downloads"

  rm -rf "${CHOOSENIM_DIR}/current"
  choosenim update $NIM_VERSION --yes ${CHOOSENIM_ARGS:-}

  # Workaround for error in choosenim on GitHub Actions windows-latest:
  # 'Unable to extract. Error was 'Cannot create a file when that file already exists.'
  # We pre-fetch the DLLs and add them to PATH so choosenim doesn't try to
  # fetch and extract.
  rm -rf "${CHOOSENIM_DIR}/downloads"

  choosenim $NIM_VERSION --yes ${CHOOSENIM_ARGS:-}
}

collect_project_metadata () {
  # Collect and export metadata about the Nim project

  # Autodetect the location of the nim project if not explicitly provided
  # as either $1 or $NIM_PROJECT_DIR.
  export NIM_PROJECT_DIR="${1:-${NIM_PROJECT_DIR:-}}"
  if [[ -z "$NIM_PROJECT_DIR" ]]
  then
    local NIMBLE_FILE=$(find_nimble_file "${PWD}")
    export NIM_PROJECT_DIR=$(dirname "$NIMBLE_FILE")
  else
    local NIMBLE_FILE=$(find_nimble_file "$NIM_PROJECT_DIR")
  fi

  cd "$NIM_PROJECT_DIR"

  # Make absolute
  export NIM_PROJECT_DIR=$(pwd)

  export NIM_PROJECT_NAME=$(basename "$NIMBLE_FILE" | sed -n 's/\(.*\)\.nimble$/\1/p')

  export NIM_PROJECT_VERSION=$(\
    nimble dump \
      | grep version: \
      | sed -e 's/version: //g' \
      | sed -e 's/"*//g')

  export ARTIFACTS_DIR="${ARTIFACTS_DIR:-${NIM_PROJECT_DIR}/artifacts}"
  mkdir -p "$ARTIFACTS_DIR"

  export SRC_DIR=$(\
    nimble dump \
      | grep srcDir: \
      | sed -e 's/srcDir: //g' \
      | sed -e 's/"*//g')

  # Make absolute
  export SRC_DIR="${NIM_PROJECT_DIR}/${SRC_DIR}"

  if [[ ! -z "$(nimble dump | grep '^bin: ""')" ]]
  then
    # nimble file does not specify bins, this is a library
    # See https://github.com/nim-lang/nimble#libraries
    export NIM_PROJECT_TYPE="library"
    export BIN_DIR=""
  else
    if [[ -d "${SRC_DIR}/${NIM_PROJECT_NAME}pkg" ]]
    then
      # See https://github.com/nim-lang/nimble#hybrids
      export NIM_PROJECT_TYPE="hybrid"
    else
      # See https://github.com/nim-lang/nimble#binary-packages
      export NIM_PROJECT_TYPE="binary"
    fi

    export BIN_DIR=$(\
      nimble dump \
        | grep 'binDir:' \
        | sed -e 's/binDir: //g' \
        | sed -e 's/"*//g')

    if [[ -z "$BIN_DIR" ]]
    then
      # If binDir isn't specified, nimble dumps bins into the project directory
      export BIN_DIR=.
    fi
    # Make absolute
    export BIN_DIR="${NIM_PROJECT_DIR}/${BIN_DIR}"
    mkdir -p "${BIN_DIR}"
  fi
  cd - &>/dev/null
}

install_nim_project () {
  # If the project is a library, install it.
  # If the project exports binaries, build them.
  cd "$NIM_PROJECT_DIR"

  if [[ "$NIM_PROJECT_TYPE" == "binary" || "$NIM_PROJECT_TYPE" == "hybrid" ]]
  then
    # Build & install binaries
    nimble install -y
  else
    # Install library, symlinked
    nimble develop -y
  fi
  cd - &>/dev/null
}

make_bin_artifacts () {
  # Handle the single bin case
  for BIN in "${NIM_PROJECT_DIR}/bin"/*
  do
    local BIN_NAME=$(basename "$BIN")
    local SUFFIX="-${NIM_PROJECT_VERSION}-${HOST_OS}_${HOST_CPU}${BIN_EXT}"
    local BIN_DIST_NAME="$(echo "$BIN_NAME" | sed "s/${BIN_EXT}\$/$SUFFIX/")"
    local BIN_DIST_PATH="${ARTIFACTS_DIR}/${BIN_DIST_NAME}"
    cp "$BIN" "$BIN_DIST_PATH"
    echo "Made bin artifact $BIN_DIST_PATH"
  done
}

make_source_artifact () {
  if [[ "$HOST_OS" == "windows" ]]
  then
    local ZIP_EXT=".zip"
  else
    local ZIP_EXT=".tar.gz"
  fi
  local ARCHIVE="${ARTIFACTS_DIR}/${NIM_PROJECT_NAME}-${NIM_PROJECT_VERSION}${ZIP_EXT}"
  cd "${NIM_PROJECT_DIR}"
  git archive --output="${ARCHIVE}" HEAD .
  cd - &>/dev/null
  echo "Made source artifact $ARCHIVE"
}

all_the_things () {
  install_nim_project

  cd "$NIM_PROJECT_DIR"
  nimble test
  cd - &>/dev/null

  if [[ "$NIM_PROJECT_TYPE" == "binary" || "$NIM_PROJECT_TYPE" == "hybrid" ]]
  then
    echo "$NIM_PROJECT_NAME is a $NIM_PROJECT_TYPE, making bin artifact"
    make_bin_artifacts
  else
    echo "$NIM_PROJECT_NAME is a $NIM_PROJECT_TYPE, not making bin artifact"
  fi
  echo "Making source artifact"
  make_source_artifact
}

install_nim () {
  # Check if Nim@NIM_VERSION is already installed, and if not, install it.
  if [[ "$NIM_VERSION" == "stable" \
        && "$(installed_nim_version)" == "$(stable_nim_version)" ]]
  then
    echo "Nim stable ($(stable_nim_version)) already installed"
    return $RET_OK
  fi

  if [[ "$NIM_VERSION" != "devel" \
        && ( "$(installed_nim_version)" == "$NIM_VERSION" \
             || "$(installed_nim_version)" == "v${NIM_VERSION}" ) ]]
  then
    echo "Nim $NIM_VERSION already installed"
    return $RET_OK
  fi

  add_path "${NIMBLE_DIR}/bin"

  if [[ "$USE_CHOOSENIM" == "yes" ]]
  then
    install_nim_with_choosenim
    local RET=$?
  else
    # fallback for platforms that don't have choosenim binaries
    install_nim_nightly_or_build_nim
    local RET=$?
  fi

  return $RET
}

join_string_array () {
  # Join elements of a bash array (second arg) with a delimiter (first arg) and
  # echo the result.
  local d=$1;
  shift;
  local f=$1;
  shift;
  printf %s "$f" "${@/#/$d}";
}

find_nimble_file () {
  echo $(\
    find "$1" -type f -name "*.nimble" -print \
        | awk '{ print gsub(/\//, "/"), $0 | "sort -n" }' \
        | head -n 1 \
        | sed 's/^[0-9] //')
}

init () {
  # Initialize and normalize env vars, then install Nim.

  # Use Nim stable if NIM_VERSION not set.
  # An earlier version of this script used BRANCH as the env var name.
  export NIM_VERSION=${NIM_VERSION:-${BRANCH:-${CHOOSENIM_CHOOSE_VERSION:-"stable"}}}
  export CHOOSENIM_CHOOSE_VERSION="$NIM_VERSION"

  # Default to no choosenim analytics, unless explicitly requested
  export CHOOSENIM_NO_ANALYTICS=${CHOOSENIM_NO_ANALYTICS:-1}

  export CHOOSENIM_DIR=${CHOOSENIM_DIR:-"${HOME}/.choosenim"}
  export NIMBLE_DIR=${NIMBLE_DIR:-"${HOME}/.nimble"}

  case $HOST_OS in
    # Work around https://github.com/nim-lang/Nim/issues/12337 fixed in 1.0+
    macosx) ulimit -n 8192 ;;
  esac

  case "${USE_CHOOSENIM:-auto}" in
    1|y|yes|true) export USE_CHOOSENIM="yes" ;;
    0|n|no|false) export USE_CHOOSENIM="no" ;;
    auto)
      # Autodetect whether to use choosenim or build Nim from source, based on
      # architecture
      case "$HOST_CPU" in
        amd64) export USE_CHOOSENIM="yes" ;;
        # choosenim doesn't have binaries for non-amd64 yet
        *) export USE_CHOOSENIM="no" ;;
      esac
      ;;
    *)
      echo "Unknown value for USE_CHOOSENIM: $USE_CHOOSENIM"
      exit 1
      ;;
  esac

  install_nim
  if [[ "$?" != 0 ]]
  then
    echo "Error installing Nim $NIM_VERSION"
    exit 1
  fi

  collect_project_metadata

  # Dump config for debugging.
  VARNAMES=(
    "ARTIFACTS_DIR" "BIN_DIR" "BIN_EXT" "CHOOSENIM_DIR" "HOST_CPU" "HOST_OS" \
    "NIM_PROJECT_DIR" "NIM_PROJECT_NAME" "NIM_PROJECT_TYPE" "NIM_VERSION" \
    "NIMBLE_DIR" "SRC_DIR" "USE_CHOOSENIM" )
  echo
  echo ">>> nim-ci config >>>"
  echo
  for VARNAME in "${VARNAMES[@]}"
  do
    eval "echo \"${VARNAME}::\$(echo \$${VARNAME})\""
  done
  echo
  echo "<<< nim-ci config <<<"
  echo

  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]
  then
    # Echoing ::set-output makes these variables available in subsequent
    # GitHub actions steps via
    # ${{ steps.<step-id>.outputs.VARNAME }}
    # where <step-id> is the YAML id: for the  step that ran this script.
    for VARNAME in "${VARNAMES[@]}"
    do
      eval echo "::set-output name=${VARNAME}::$(echo '$VARNAME')"
    done
  fi
}

export NIM_CI_CACHE="${HOME}/.cache/nim-ci"
mkdir -p "${NIM_CI_CACHE}/bin"
add_path "${NIM_CI_CACHE}/bin"

export HOST_OS=$(normalize_to_host_os "$(uname)")
export HOST_CPU=$(normalize_to_host_cpu "$(uname -m)")
export BIN_EXT=""

case $HOST_OS in
  windows) export BIN_EXT=".exe" ;;
esac

case "${INIT_NIM_CI:-"yes"}" in 1|y|yes|true) init ;; esac
