#!/bin/bash

set -ex

# Use nim stable if NIM_VERSION not set.
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

add_path () {
  # Add an entry to PATH
  export PATH="$1:$PATH"
  echo "::add-path::$1" # Github Actions syntax for adding to path
}

normalize_cpu_arch() {
  # Normalize the CPU_ARCH env var to match nim's system.hostCPU values.
  # If CPU_ARCH is not provided, the architecture is inferred.
  # CPU_ARCH becomes one of:
  # * i386
  # * amd64
  # * arm64
  # * arm
  # * ppc64le

  if [[ ! -z "$TRAVIS_CPU_ARCH" ]]
  then
    # Travis supplies TRAVIS_CPU_ARCH as one of amd64, arm64, ppc64le
    export CPU_ARCH="$TRAVIS_CPU_ARCH"
  fi

  if [[ -z "$CPU_ARCH" ]]
  then
    export CPU_ARCH=`uname -m`
  fi

  export CPU_ARCH=`echo $CPU_ARCH | tr "[:upper:]" "[:lower:]"`

  case $CPU_ARCH in
    *amd*64* | *x86*64* ) export CPU_ARCH="amd64" ;;
    *x86* | *i*86* ) export CPU_ARCH="i386" ;;
    *aarch64*|*arm64* ) export CPU_ARCH="arm64" ;;
    *arm* ) export CPU_ARCH="arm" ;;
    *ppc64le* ) export CPU_ARCH="powerpc64el" ;;
  esac
}

normalize_os_name () {
  # Normalize the OS_NAME env var to match nim's system.hostOS values.
  # If OS_NAME is not provided, the OS is inferred.
  # OS_NAME becomes one of:
  # * linux
  # * macosx
  # * windows

  if [[ ! -z "$TRAVIS_OS_NAME" ]]
  then
    # Travis supplies TRAVIS_OS_NAME as one of linux, osx, windows
    export OS_NAME="$TRAVIS_OS_NAME"
  fi

  if [[ -z "$OS_NAME" ]]
  then
    export OS_NAME=`uname`
  fi

  export OS_NAME=`echo $OS_NAME | tr "[:upper:]" "[:lower:]"`

  case $OS_NAME in
    *linux* | *ubuntu* | *alpine* ) export CPU_ARCH="linux" ;;
    *darwin* | *macos* | *osx* ) export CPU_ARCH="macosx" ;;
    *mingw* | *msys* | *windows* ) export CPU_ARCH="windows" ;;
  esac
}

download_nightly() {
  # Try to download a nightly nim build from https://github.com/nim-lang/nightlies/releases
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
    # intermittently, in which case the script will fallback to building nim.
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
    return 1
  fi

  return 0
}

build_nim () {
  # Build nim from scratch, sans choosenim
  if [[ "$NIM_VERSION" == "devel" ]]
  then
    if [[ "$BUILD_NIM" != 1 ]]
    then
      # If not forcing build, try downloading nightly build
      download_nightly
      local DOWNLOADED=$?
      if [[ "$DOWNLOADED" == "1" ]]
      then
        # Nightly build was downloaded
        return
      fi
    fi
    # Note: don't cache $HOME/Nim-devel in your .travis.yml
    local NIMREPO=$HOME/Nim-devel
  else
    # Not actually using choosenim, but cache in same location.
    local NIMREPO=$HOME/.choosenim/toolchains/nim-$NIM_VERSION-$CPU_ARCH
  fi

  add_path $NIMREPO/bin

  if [[ -f "$NIMREPO/bin/nim" ]]
  then
    echo "Using cached nim $NIMREPO"
  else
    echo "Building nim $NIM_VERSION"
    if [[ "$NIM_VERSION" =~ [0-9] ]]
    then
      local GITREF="v$NIM_VERSION" # version tag
    else
      local GITREF=$NIM_VERSION
    fi
    git clone -b $GITREF --single-branch https://github.com/nim-lang/Nim.git $NIMREPO
    cd $NIMREPO
    sh build_all.sh
    cd -
  fi
}

use_choosenim () {
  # Using choosenim, install a nim binary or build nim from scratch
  local GITBIN=$HOME/.choosenim/git/bin
  export CHOOSENIM_CHOOSE_VERSION="$NIM_VERSION --latest"
  export CHOOSENIM_NO_ANALYTICS=1

  add_path $GITBIN
  add_path $HOME/.nimble/bin

  if ! type -P choosenim &> /dev/null
  then
    echo "Installing choosenim"

    mkdir -p $GITBIN
    if [[ "$OS_NAME" == "windows" ]]
    then
      export EXT=.exe
      # Setup git outside "Program Files", space breaks cmake sh.exe
      cd $GITBIN/..
      curl -L -s "https://github.com/git-for-windows/git/releases/download/v2.23.0.windows.1/PortableGit-2.23.0-64-bit.7z.exe" -o portablegit.exe
      7z x -y -bd portablegit.exe
      cd -
    fi

    curl https://nim-lang.org/choosenim/init.sh -sSf > init.sh
    sh init.sh -y
    cp $HOME/.nimble/bin/choosenim$EXT $GITBIN/.

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

main () {
  normalize_os_name
  normalize_cpu_arch

  echo "Platform is ${OS_NAME}_${CPU_ARCH}"

  if [[ "$OS_NAME" == "macosx" ]]
  then
    # Work around https://github.com/nim-lang/Nim/issues/12337 fixed in 1.0+
    ulimit -n 8192
  fi

  # Autodetect whether to build nim or use choosenim, based on architecture.
  # Force nim build with BUILD_NIM=1
  # Force choosenim with USE_CHOOSENIM=1
  if [[ ( "$CPU_ARCH" != "amd64" || "$BUILD_NIM" == "1" ) && "$USE_CHOOSENIM" != "1" ]]
  then
    build_nim
  else
    use_choosenim
  fi
}

main

