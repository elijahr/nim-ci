#!/bin/bash

set -euo pipefail
# set -u

# TODO - keep this or nah?
export CHOOSENIM_NO_ANALYTICS=1

# return codes
export RET_OK=0
export RET_ERROR=1

add_path () {
  # Add an entry to PATH
  export PATH="$1:$PATH"
  echo "::add-path::$1" # GitHub Actions syntax for adding to path across steps
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
    *amd*64* | *x86*64* ) local CPU="amd64" ;;
    *x86* | *i*86* ) local CPU="i386" ;;
    *aarch64*|*arm64* ) local CPU="arm64" ;;
    *arm* ) local CPU="arm" ;;
    *ppc64le* ) local CPU="powerpc64el" ;;
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
    *linux* | *ubuntu* | *alpine* ) local OS="linux" ;;
    *darwin* | *macos* | *osx* ) local OS="macosx" ;;
    *mingw* | *msys* | *windows* ) local OS="windows" ;;
  esac

  echo $OS
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
    local NIGHTLY_API_URL=https://api.github.com/repos/nim-lang/nightlies/releases

    local NIGHTLY_DOWNLOAD_URL=$(curl $NIGHTLY_API_URL -SsLf \
      | grep "\"browser_download_url\": \".*${SUFFIX}\"" \
      | head -n 1 \
      | sed -n 's/".*\(https:.*\)".*/\1/p')
  fi

  if [[ ! -z "$NIGHTLY_DOWNLOAD_URL" ]]
  then
    mkdir -p "${HOME}/.cache/nim-ci/nim-nightlies"
    local NIGHTLY_ARCHIVE="${HOME}/.cache/nim-ci/nim-nightlies/$(basename $NIGHTLY_DOWNLOAD_URL)"
    curl $NIGHTLY_DOWNLOAD_URL -SsLf -o $NIGHTLY_ARCHIVE
  else
    echo "No nightly build available for $HOST_OS $HOST_CPU"
    local NIGHTLY_ARCHIVE=""
  fi

  local NIM_DIR="${HOME}/Nim-devel"
  if [[ ! -z "$NIGHTLY_ARCHIVE" && -f "$NIGHTLY_ARCHIVE" ]]
  then
    rm -Rf "$NIM_DIR"
    mkdir -p "$NIM_DIR"
    if [[ "$HOST_OS" == "windows" ]]
    then
      unzip -q "$NIGHTLY_ARCHIVE" -d "$NIM_DIR"
      local UNZIP_DIR=$(find "$NIM_DIR" -type d -name "nim-*" -print -quit \
        | head -n 1)
      if [[ ! -z "$UNZIP_DIR" ]]
      then
        mv "$UNZIP_DIR"/* "$NIM_DIR/"
      fi
    else
      tar -xf "$NIGHTLY_ARCHIVE" -C "$NIM_DIR" --strip-components=1
    fi
    rm "$NIGHTLY_ARCHIVE"

    if [[ -f "$NIM_DIR/bin/nim${BIN_EXT}" ]]
    then
      add_path "$NIM_DIR/bin"
      echo "Installed nightly build $NIGHTLY_DOWNLOAD_URL"
      return $RET_OK
    else
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
      | sed 's/^.*tags\///')"
  fi
  echo "$NIM_STABLE_VERSION"
}

installed_nim_version () {
  # Echoes the tag name of the installed version of Nim
  if type -P nim &> /dev/null
  then
    echo `nim -v | head -n 1 | sed -n 's/.*Version \(.*\) \\[.*/v\1/p'`
  fi
}

install_nim_nightly_or_build_nim () {
  # Build Nim from source, sans choosenim
  if [[ "$NIM_VERSION" == "devel" ]]
  then
    # Try downloading nightly build
    download_nightly
    if [[ "$?" == "$RET_OK" ]]
    then
      # Nightly build was downloaded
      return $RET_OK
    fi
    # Note: don't cache $HOME/Nim-devel between builds
    local NIMREPO=$HOME/Nim-devel
  else
    # Not actually using choosenim, but cache in same location.
    local NIMREPO=$HOME/.choosenim/toolchains/nim-$NIM_VERSION-$HOST_CPU
  fi

  add_path "${NIMREPO}/bin"

  if [[ -f "$NIMREPO/bin/nim" ]]
  then
    echo "Using cached Nim $NIMREPO"
    return $RET_OK
  else
    echo "Building Nim $NIM_VERSION"
    if [[ "$NIM_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]
    then
       # Semantic version tag
      local GITREF="v$NIM_VERSION"
    else
      if [[ "$NIM_VERSION" == "stable" ]]
      then
        local GITREF=$(stable_nim_version)
      else
        local GITREF=$NIM_VERSION
      fi
    fi
    cd $NIMREPO
    curl "https://api.github.com/repos/nim-lang/Nim/tarball/${GITREF}" -LsSf -o Nim.tar.gz
    tar -xzf Nim.tar.gz -C .
    cd nim-lang-Nim-*
    sh build_all.sh
    cd -
    cd -
    return $RET_OK
  fi
}

install_windows_git () {
  # Acquire git
  local GITBIN="${HOME}/.cache/nim-ci/git/bin"
  mkdir -p "$GITBIN"
  add_path "$GITBIN"
  # Setup git outside "Program Files", space breaks cmake sh.exe
  cd "$GITBIN/.."
  local PORTABLE_GIT=https://github.com/git-for-windows/git/releases/download/v2.23.0.windows.1/PortableGit-2.23.0-64-bit.7z.exe
  curl -L -s $PORTABLE_GIT -o portablegit.exe
  7z x -y -bd portablegit.exe
  cd -
}

install_nim_with_choosenim () {
  # Install a Nim binary or build Nim from source, using choosenim
  if ! type -P choosenim &> /dev/null
  then
    echo "Installing choosenim"
    if [[ "$HOST_OS" == "windows" ]]
    then
      install_windows_git
    fi

    curl https://nim-lang.org/choosenim/init.sh -sSf -o choosenim-init.sh
    sh choosenim-init.sh -y
    # cp "${HOME}/.nimble/bin/choosenim$BIN_EXT" "${GITBIN}/"

    # # Copy DLLs for choosenim
    # if [[ "$HOST_OS" == "windows" ]]
    # then
    #   cp "${HOME}/.nimble/bin"/*.dll "${GITBIN}/"
    # fi
    echo "Installed choosenim"
  else
    echo "choosenim already installed"
  fi

  # rm -rf "${HOME}/.choosenim/current"
  choosenim update $NIM_VERSION --yes
  choosenim $NIM_VERSION --yes
}

detect_nim_project_type () {
  # Determine if project exports a binary executable or is a library
  cd "$NIM_PROJECT_DIR"

  local thenimble="$(which nimble || true)"
  echo "which nimble is ${thenimble}"
  if [[ -f "$thenimble" ]]
  then
    echo "$thenimble is a file"
  else
    echo "$thenimble is NOT a file"
  fi
  export SRC_DIR=$(\
    nimble dump \
      | grep srcDir: \
      | sed -e 's/srcDir: //g' \
      | sed -e 's/"*//g')

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
    export BIN_DIR=$(cd "$BIN_DIR"; pwd)
  fi
  cd -
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
  cd -
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
  # TODO - Better the multi-bin case - a zipball?
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
  cd -
  echo "Made source artifact $ARCHIVE"
}

all_the_things () {
  install_nim_project

  cd "$NIM_PROJECT_DIR"
  nimble test
  cd -

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

  add_path "${HOME}/.nimble/bin"

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
  export NIM_VERSION=${NIM_VERSION:-${BRANCH:-"stable"}}

  export HOST_OS=$(normalize_to_host_os "$(uname)")
  export HOST_CPU=$(normalize_to_host_cpu "$(uname -m)")

  export BIN_EXT=""

  case $HOST_OS in
    macosx)
      # Work around https://github.com/nim-lang/Nim/issues/12337 fixed in 1.0+
      ulimit -n 8192
      ;;
    windows)
      export BIN_EXT=.exe
      ;;
  esac

  # Autodetect whether to use choosenim or build Nim from source, based on
  # architecture
  if [[ -z "${USE_CHOOSENIM:-}" ]]
  then
    case "$HOST_CPU" in
      amd64) export USE_CHOOSENIM=yes ;;
      # choosenim doesn't have binaries for non-amd64 yet
      *) export USE_CHOOSENIM=no ;;
    esac
  else
    # normalize
    case "$USE_CHOOSENIM" in
      yes|true|1) export USE_CHOOSENIM=yes ;;
      *) export USE_CHOOSENIM=no ;;
    esac
  fi

  # Autodetect the location of the nim project if not explicitly provided.
  if [[ -z "${NIM_PROJECT_DIR:-}" ]]
  then
    local NIMBLE_FILE=$(find_nimble_file .)
    export NIM_PROJECT_DIR=$(dirname "$NIMBLE_FILE")
  else
    local NIMBLE_FILE=$(find_nimble_file "$NIM_PROJECT_DIR")
  fi

  # Make NIM_PROJECT_DIR absolute
  export NIM_PROJECT_DIR=$(cd "$NIM_PROJECT_DIR"; pwd)
  export NIM_PROJECT_NAME=$(basename "$NIMBLE_FILE" | sed -n 's/\(.*\)\.nimble$/\1/p')

  install_nim
  if [[ "$?" != 0 ]]
  then
    echo "Error installing Nim"
    exit 1
  fi

  cd "$NIM_PROJECT_DIR"
  export NIM_PROJECT_VERSION=$(\
    nimble dump \
      | grep version: \
      | sed -e 's/version: //g' \
      | sed -e 's/"*//g')
  cd -

  export ARTIFACTS_DIR="${ARTIFACTS_DIR:-${NIM_PROJECT_DIR}/artifacts}"
  mkdir -p "$ARTIFACTS_DIR"
  detect_nim_project_type

  # Dump config for debugging.
  VARNAMES=(
    "ARTIFACTS_DIR" "BIN_DIR" "BIN_EXT" "HOST_CPU" "HOST_OS" "NIM_PROJECT_DIR" \
    "NIM_PROJECT_NAME" "NIM_PROJECT_TYPE" "NIM_VERSION" "SRC_DIR" \
    "USE_CHOOSENIM" )
  echo
  echo ">>> nim-ci config >>>"
  echo
  for VARNAME in "${VARNAMES[@]}"
  do
    eval echo "${VARNAME}::$(echo '$VARNAME')"
  done
  echo
  echo "<<< nim-ci config <<<"
  echo

  if [[ ! -z "${GITHUB_WORKFLOW:-}" ]]
  then
    # Echoing ::set-output makes these variables available in subsequent
    # GitHub Actions steps via
    # ${{ steps.<step-id>.outputs.VARNAME }}
    # where <step-id> is the YAML id: for the  step that ran this script.
    for VARNAME in "${VARNAMES[@]}"
    do
      eval echo "::set-output name=${VARNAME}::$(echo '$VARNAME')"
    done
  fi
}

init
