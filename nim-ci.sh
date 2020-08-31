#!/bin/bash

set -ex

# TODO - keep this or nah?
export CHOOSENIM_NO_ANALYTICS=1

# return codes
export RET_DOWNLOADED=0
export RET_NOT_DOWNLOADED=1

add_path () {
  # Add an entry to PATH
  export PATH="$1:$PATH"
  echo "::add-path::$1" # GitHub Actions syntax for adding to path across steps
  echo "Added $1 to PATH"
}

normalize_cpu_arch() {
  # Normalize a CPU architecture string to match Nim's system.hostCPU values.
  # The echo'd value is one of:
  # * i386
  # * amd64
  # * arm64
  # * arm
  # * ppc64le

  local cpu_arch=`echo $1 | tr "[:upper:]" "[:lower:]"`

  case $cpu_arch in
    *amd*64* | *x86*64* ) local cpu_arch="amd64" ;;
    *x86* | *i*86* ) local cpu_arch="i386" ;;
    *aarch64*|*arm64* ) local cpu_arch="arm64" ;;
    *arm* ) local cpu_arch="arm" ;;
    *ppc64le* ) local cpu_arch="powerpc64el" ;;
  esac

  echo $cpu_arch
}

normalize_os_name () {
  # Normalize an OS name string to match Nim's system.hostOS values.
  # The echo'd value is one of:
  # * linux
  # * macosx
  # * windows

  local os_name=`echo $1 | tr "[:upper:]" "[:lower:]"`

  case $os_name in
    *linux* | *ubuntu* | *alpine* ) local os_name="linux" ;;
    *darwin* | *macos* | *osx* ) local os_name="macosx" ;;
    *mingw* | *msys* | *windows* ) local os_name="windows" ;;
  esac

  echo $os_name
}

download_nightly() {
  # Try to download a nightly Nim build from https://github.com/nim-lang/nightlies/releases
  # Returns 0 if download was succesful, 1 otherwise.
  if [[ "$OS_NAME" == "linux" ]]
  then
    if [[ "$CPU_ARCH" == "amd64" ]]
    then
      local SUFFIX="linux_x64\.tar\.xz"
    else
      # linux_arm64, etc
      local SUFFIX="linux_${CPU_ARCH}\.tar\.xz"
    fi
  elif [[ "$OS_NAME" == "macosx" ]]
  then
    if [[ "$CPU_ARCH" == "amd64" ]]
    then
      # Used to be osx.tar.xz, now is macosx_x64.tar.xz
      local SUFFIX="macosx_x64\.tar\.xz"
    else
      # macosx_arm64, perhaps someday
      local SUFFIX="macosx_${CPU_ARCH}\.tar\.xz"
    fi
  elif [[ "$OS_NAME" == "windows" ]]
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
    local NIGHTLY_ARCHIVE=$(basename $NIGHTLY_DOWNLOAD_URL)
    curl $NIGHTLY_DOWNLOAD_URL -SsLf > $NIGHTLY_ARCHIVE
  else
    echo "No nightly build available for $OS_NAME $CPU_ARCH"
  fi

  if [[ ! -z "$NIGHTLY_ARCHIVE" && -f "$NIGHTLY_ARCHIVE" ]]
  then
    rm -Rf $HOME/Nim-devel
    mkdir -p $HOME/Nim-devel
    tar -xf $NIGHTLY_ARCHIVE -C $HOME/Nim-devel --strip-components=1
    rm $NIGHTLY_ARCHIVE
    add_path $HOME/Nim-devel/bin
    echo "Installed nightly build $NIGHTLY_DOWNLOAD_URL"
    return $RET_DOWNLOADED
  fi

  return $RET_NOT_DOWNLOADED
}

install_nim_nightly_or_build_nim () {
  # Build Nim from source, sans choosenim
  if [[ "$NIM_VERSION" == "devel" ]]
  then
    # Try downloading nightly build
    download_nightly
    if [[ "$?" == "$RET_DOWNLOADED" ]]
    then
      # Nightly build was downloaded
      return
    fi
    # Note: don't cache $HOME/Nim-devel between builds
    local NIMREPO=$HOME/Nim-devel
  else
    # Not actually using choosenim, but cache in same location.
    local NIMREPO=$HOME/.choosenim/toolchains/nim-$NIM_VERSION-$CPU_ARCH
  fi

  add_path $NIMREPO/bin

  if [[ -f "$NIMREPO/bin/nim" ]]
  then
    echo "Using cached Nim $NIMREPO"
  else
    echo "Building Nim $NIM_VERSION"
    if [[ "$NIM_VERSION" =~ [0-9] ]]
    then
      local GITREF="v$NIM_VERSION" # version tag
    else
      local GITREF=$NIM_VERSION
    fi
    git clone -b $GITREF --depth 1 --single-branch https://github.com/nim-lang/Nim.git $NIMREPO
    cd $NIMREPO
    sh build_all.sh
    # back to prev directory
    cd -
  fi
}

install_nim_with_choosenim () {
  # Install a Nim binary or build Nim from source, using choosenim
  local GITBIN=$HOME/.choosenim/git/bin

  add_path $GITBIN
  add_path $HOME/.nimble/bin

  if ! type -P choosenim &> /dev/null
  then
    echo "Installing choosenim"

    mkdir -p $GITBIN
    if [[ "$OS_NAME" == "windows" ]]
    then
      # Setup git outside "Program Files", space breaks cmake sh.exe
      cd $GITBIN/..
      curl -L -s "https://github.com/git-for-windows/git/releases/download/v2.23.0.windows.1/PortableGit-2.23.0-64-bit.7z.exe" -o portablegit.exe
      7z x -y -bd portablegit.exe
      # back to prev directory
      cd -
    fi

    curl https://nim-lang.org/choosenim/init.sh -sSf > init.sh
    sh init.sh -y
    cp $HOME/.nimble/bin/choosenim$BIN_EXT $GITBIN/.

    # Copy DLLs for choosenim
    if [[ "$OS_NAME" == "windows" ]]
    then
      cp $HOME/.nimble/bin/*.dll $GITBIN/.
    fi
  else
    echo "choosenim already installed"
    rm -rf $HOME/.choosenim/current
    choosenim update $NIM_VERSION --latest
    choosenim $NIM_VERSION
  fi
}

detect_nim_project_type () {
  # Determine if project exports a binary executable or is a library
  cd "$NIM_PROJECT_DIR"

  # Array of executables this project installs, as defined in the foo.nimble bin: @[] sequence
  export BINS=($(echo `nimble dump | grep bin: | sed -e 's/bin: //g' | sed -e 's/"*//g'` | tr "," "\n"))
  export BIN_DIR=`nimble dump | grep binDir: | sed -e 's/binDir: //g' | sed -e 's/"*//g'`

  if [[ ${#BINS[@]} -eq 0 ]]
  then
    export NIM_PROJECT_TYPE="library"
  else
    export NIM_PROJECT_TYPE="executables"
    if [[ -z "$BIN_DIR" ]]
    then
      # If binDir isn't specified, nimble dumps them into the project directory
      export BIN_DIR=.
    fi
    export BIN_DIR=${NIM_PROJECT_DIR}/${BIN_DIR}
  fi

  # back to prev directory
  cd -
}

build_nim_project () {
  # If the project is a library, install it.
  # If the project exports executables, build it.
  cd "$NIM_PROJECT_DIR"

  if [[ "$NIM_PROJECT_TYPE" == "executables" ]]
  then
    # Build & install executables
    nimble install -y
  else
    # Install library, symlinked
    nimble develop -y
  fi

  # back to prev directory
  cd -
}

export_bin_artifacts () {
  # Export binary executables if the Nim project is configured to do so.
  # If the Nim project is a library, this is a no-op.
  if [[ "$NIM_PROJECT_TYPE" == "executables" ]]
  then
    mkdir -p $DIST_DIR
    for BIN in "${BINS[@]}"
    do
      cp "${BIN_DIR}/${BIN}${BIN_EXT}" "${DIST_DIR}/"
    done
    tar -c --lzma -f "${ZIP_PATH}" "$DIST_DIR"

    if [[ ! -z "$GITHUB_WORKFLOW" ]]
    then
      echo ::set-output name=zip_name::$ZIP_NAME
      echo ::set-output name=zip_contents::$(cat "$ZIP_PATH")
    fi
  fi
}


install_nim () {
  if [[ "$USE_CHOOSENIM" == "yes" ]]
  then
    install_nim_with_choosenim
  else
    # fallback for platforms that don't have choosenim binaries
    install_nim_nightly_or_build_nim
  fi
}


join_string_array () {
  # Join elements of a bash array (second arg) with a delimiter (first arg) and echo the result.
  local d=$1;
  shift;
  local f=$1;
  shift;
  printf %s "$f" "${@/#/$d}";
}


init () {
  # Initialize env vars to their defaults.

  # Use Nim stable if NIM_VERSION not set.
  # An earlier version of this script used BRANCH as the env var name.
  if [[ -z "$NIM_VERSION" ]]
  then
    if [[ -z "$BRANCH" ]]
    then
      export NIM_VERSION=stable
    else
      # fallback to old env var name BRANCH
      export NIM_VERSION="$BRANCH"
    fi
  fi

  if [[ -z "$CHOOSENIM_CHOOSE_VERSION" ]]
  then
    export CHOOSENIM_CHOOSE_VERSION="$NIM_VERSION --latest"
  fi

  # Setup and normalize various environment variables.
  if [[ ! -z "$TRAVIS_OS_NAME" ]]
  then
    # Travis supplies TRAVIS_OS_NAME as one of linux, osx, windows
    export OS_NAME="$TRAVIS_OS_NAME"
  fi

  if [[ -z "$OS_NAME" ]]
  then
    # Infer OS_NAME if not explicitly provided
    export OS_NAME=`uname`
  fi

  export OS_NAME=$(normalize_os_name $OS_NAME)

  if [[ ! -z "$TRAVIS_CPU_ARCH" ]]
  then
    # Travis supplies TRAVIS_CPU_ARCH as one of amd64, arm64, ppc64le
    export CPU_ARCH="$TRAVIS_CPU_ARCH"
  fi

  if [[ -z "$CPU_ARCH" ]]
  then
    # Infer CPU_ARCH if not explicitly provided
    export CPU_ARCH=`uname -m`
  fi

  export CPU_ARCH=$(normalize_cpu_arch $CPU_ARCH)

  export BIN_EXT=""
  export ZIP_EXT=".xz"

  case $OS_NAME in
    macosx)
      # Work around https://github.com/nim-lang/Nim/issues/12337 fixed in 1.0+
      ulimit -n 8192
      ;;
    windows)
      export BIN_EXT=.exe
      export ZIP_EXT=.zip
      ;;
  esac

  # Autodetect whether to use choosenim or build Nim from source, based on architecture
  if [[ ( "$CPU_ARCH" == "amd64" || "$USE_CHOOSENIM" == "yes" ]]
  then
    export USE_CHOOSENIM=yes
  else
    export USE_CHOOSENIM=no
  fi

  # Autodetect the location of the nim project if not explicitly provided.
  if [[ -z "$NIM_PROJECT_DIR" ]]
  then
    export NIM_PROJECT_DIR=$(cd $(dirname $(find . -type f -name "*.nimble" -print -quit)); pwd)
  else
    # Make NIM_PROJECT_DIR absolute
    export NIM_PROJECT_DIR=$(cd $NIM_PROJECT_DIR; pwd)
  fi

  export NIM_PROJECT_NAME=$(ls ${NIM_PROJECT_DIR}/*.nimble | sed -n 's/\(.*\)\.nimble/\1/p')
  cd "$NIM_PROJECT_DIR"
  export NIM_PROJECT_VERSION=`nimble dump | grep version: | sed -e 's/version: //g' | sed -e 's/"*//g'`
  cd -

  export DIST_DIR="${NIM_PROJECT_DIR}/dist/${NIM_PROJECT_NAME}-${OS_NAME}_${CPU_ARCH}"
  export ZIP_NAME="${NIM_PROJECT_NAME}-${OS_NAME}_${CPU_ARCH}${ZIP_EXT}"
  export ZIP_PATH="${NIM_PROJECT_DIR}/dist/${ZIP_NAME}"

  detect_nim_project_type

  echo "nim-ci config:"
  echo
  echo "  OS_NAME=$OS_NAME"
  echo "  CPU_ARCH=$CPU_ARC"
  echo "  NIM_VERSION=$NIM_VERSION"
  echo "  NIM_PROJECT_DIR=$NIM_PROJECT_DIR"
  echo "  NIM_PROJECT_NAME=$NIM_PROJECT_NAME"
  echo "  NIM_PROJECT_TYPE=$NIM_PROJECT_TYPE"
  echo "  BINS=$(join_string_array ', ' $BINS)"
  echo "  BIN_DIR=$BIN_DIR"
  echo "  BIN_EXT=$BIN_EXT"
  echo "  ZIP_EXT=$ZIP_EXT"
  echo "  DIST_DIR=$DIST_DIR"
  echo "  ZIP_PATH=$ZIP_NAME"
  echo "  ZIP_NAME=$ZIP_NAME"
  echo "  USE_CHOOSENIM=$USE_CHOOSENIM"
  echo
}


init
