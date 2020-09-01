#!/bin/bash

set -e

# TODO - keep this or nah?
export CHOOSENIM_NO_ANALYTICS=1

# return codes
export RET_DOWNLOADED=0
export RET_NOT_DOWNLOADED=1

declare -a BINS
BINS=()

add_path () {
  # Add an entry to PATH
  export PATH="$1:$PATH"
  echo "::add-path::$1" # GitHub Actions syntax for adding to path across steps
  echo "Added $1 to PATH"
}

normalize_to_host_cpu() {
  # Normalize a CPU architecture string to match Nim's system.hostCPU values.
  # The echo'd value is one of:
  # * i386
  # * amd64
  # * arm64
  # * arm
  # * ppc64le

  local cpu_arch=$(echo $1 | tr "[:upper:]" "[:lower:]")

  case $cpu_arch in
    *amd*64* | *x86*64* ) local cpu_arch="amd64" ;;
    *x86* | *i*86* ) local cpu_arch="i386" ;;
    *aarch64*|*arm64* ) local cpu_arch="arm64" ;;
    *arm* ) local cpu_arch="arm" ;;
    *ppc64le* ) local cpu_arch="powerpc64el" ;;
  esac

  echo $cpu_arch
}

normalize_to_host_os () {
  # Normalize an OS name string to match Nim's system.hostOS values.
  # The echo'd value is one of:
  # * linux
  # * macosx
  # * windows

  local os_name=$(echo $1 | tr "[:upper:]" "[:lower:]")

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
    mkdir -p "${HOME}/.cache/nim-ci"
    local NIGHTLY_ARCHIVE="${HOME}/.cache/nim-ci/$(basename $NIGHTLY_DOWNLOAD_URL)"
    curl $NIGHTLY_DOWNLOAD_URL -SsLf > $NIGHTLY_ARCHIVE
  else
    echo "No nightly build available for $HOST_OS $HOST_CPU"
  fi

  local NIM_DIR="${HOME}/Nim-devel"
  if [[ ! -z "$NIGHTLY_ARCHIVE" && -f "$NIGHTLY_ARCHIVE" ]]
  then
    rm -Rf "$NIM_DIR"
    mkdir -p "$NIM_DIR"
    if [[ "$ZIP_EXT" == ".zip" ]]
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
      return $RET_DOWNLOADED
    else
      echo "Error installing Nim"
    fi
  fi

  return $RET_NOT_DOWNLOADED
}

stable_nim_version () {
  # Echoes the tag name of the current stable version of Nim
  if [[ -z "$NIM_STABLE_VERSION" ]]
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
    if [[ "$?" == "$RET_DOWNLOADED" ]]
    then
      # Nightly build was downloaded
      return
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
  else
    echo "Building Nim $NIM_VERSION"
    if [[ "$NIM_VERSION" =~ [0-9] ]]
    then
      local GITREF="v$NIM_VERSION" # version tag
    else
      if [[ "$NIM_VERSION" == "stable" ]]
      then
        local GITREF=$(stable_nim_version)
      else
        local GITREF=$NIM_VERSION
      fi
    fi
    git clone -b $GITREF \
      --single-branch https://github.com/nim-lang/Nim.git \
      $NIMREPO
    cd $NIMREPO
    sh build_all.sh
    # back to prev directory
    cd -
  fi
}

install_nim_with_choosenim () {
  # Install a Nim binary or build Nim from source, using choosenim
  local GITBIN="${HOME}/.choosenim/git/bin"

  add_path "$GITBIN"

  if ! type -P choosenim &> /dev/null
  then
    echo "Installing choosenim"

    mkdir -p $GITBIN
    if [[ "$HOST_OS" == "windows" ]]
    then
      # Setup git outside "Program Files", space breaks cmake sh.exe
      cd $GITBIN/..
      local PORTABLE_GIT=https://github.com/git-for-windows/git/releases/download/v2.23.0.windows.1/PortableGit-2.23.0-64-bit.7z.exe
      curl -L -s $PORTABLE_GIT -o portablegit.exe
      7z x -y -bd portablegit.exe
      # back to prev directory
      cd -
    fi

    curl https://nim-lang.org/choosenim/init.sh -sSf > init.sh
    sh init.sh -y
    cp "${HOME}/.nimble/bin/choosenim$BIN_EXT" "${GITBIN}/"

    # Copy DLLs for choosenim
    if [[ "$HOST_OS" == "windows" ]]
    then
      cp "${HOME}/.nimble/bin"/*.dll "${GITBIN}/"
    fi
  else
    echo "choosenim already installed"
    rm -rf "${HOME}/.choosenim/current"
    choosenim update $NIM_VERSION
    choosenim $NIM_VERSION
  fi
}

detect_nim_project_type () {
  # Determine if project exports a binary executable or is a library
  cd "$NIM_PROJECT_DIR"

  # Array of binaries this project installs, as defined in the nimble file
  while IFS= read -r LINE
  do
    if [[ ! -z "$LINE" ]]
    then
      BINS+=("$LINE")
    fi
  done <<< $(echo "$(nimble dump \
    | grep bin: \
    | sed -e 's/bin: //g' \
    | sed -e 's/"*//g')" \
    | tr "," "\n")

  export BIN_DIR=$(nimble dump \
    | grep binDir: \
    | sed -e 's/binDir: //g' \
    | sed -e 's/"*//g')

  export SRC_DIR=$(nimble dump \
    | grep srcDir: \
    | sed -e 's/srcDir: //g' \
    | sed -e 's/"*//g')

  if [[ "${#BINS[@]}" == "0" ]]
  then
    # nimble file does not specify bins, this is a library
    # See https://github.com/nim-lang/nimble#libraries
    export NIM_PROJECT_TYPE="library"
  else
    if [[ -d "${SRC_DIR}/${NIM_PROJECT_NAME}pkg" ]]
    then
      # See https://github.com/nim-lang/nimble#hybrids
      export NIM_PROJECT_TYPE="hybrid"
    else
      # See https://github.com/nim-lang/nimble#binary-packages
      export NIM_PROJECT_TYPE="binary"
    fi
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

  # back to prev directory
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

  # back to prev directory
  cd -
}

make_zipball () {
  # Export binaries and text files if NIM_PROJECT_TYPE is binary or hybrid, or
  # if the user has placed anything in DIST_DIR. Otherwise, this is a no-op.
  if [[ "$NIM_PROJECT_TYPE" == "binary" \
        || "$NIM_PROJECT_TYPE" == "hybrid"
        || ! -z "$(ls -A "${DIST_DIR}")" ]]
  then
    if [[ "${#BINS[@]}" -ge "1" \
          && ! -f "${BIN_DIR}/${BINS[0]}${BIN_EXT}" ]]
    then
      # Project has unbuilt binaries, build them
      install_nim_project
    fi

    # Copy binaries to dist dir
    for BIN in ${BINS[@]}
    do
      cp "${BIN_DIR}/${BIN}${BIN_EXT}" "${DIST_DIR}/"
    done

    # Copy readme, license, etc
    cp "${NIM_PROJECT_DIR}/"[Rr][Ee][Aa][Dd][Mm][Ee]* "${DIST_DIR}/" &> /dev/null || true
    cp "${NIM_PROJECT_DIR}/"[Ll][Ii][Cc][Ee][Nn][Ss][Ee]* "${DIST_DIR}/" &> /dev/null || true
    cp "${NIM_PROJECT_DIR}/"[Cc][Oo][Pp][Yy][Ii][Nn][Gg]* "${DIST_DIR}/" &> /dev/null || true
    cp "${NIM_PROJECT_DIR}/"[Aa][Uu][Tt][Hh][Oo][Rr][Ss]* "${DIST_DIR}/" &> /dev/null || true
    cp "${NIM_PROJECT_DIR}/"[Cc][Hh][Aa][Nn][Gg][Ee][Ll][Oo][Gg]* "${DIST_DIR}/" &> /dev/null || true
    cp "${NIM_PROJECT_DIR}/"*.txt "${DIST_DIR}/" &> /dev/null || true
    cp "${NIM_PROJECT_DIR}/"*.md "${DIST_DIR}/" &> /dev/null || true

    cd "$DIST_DIR/.."
    local DIST_NAME=$(basename "$DIST_DIR")
    tar -c --lzma -f "${ZIP_PATH}" "$DIST_NAME"
    cd -
    echo "Made zipball $ZIP_PATH"
  else
    echo "Nothing to arifact"
  fi
}

install_nim () {
  # Check if Nim@NIM_VERSION is already installed, and if not, install it.

  if [[ "$NIM_VERSION" == "stable" \
        && "$(installed_nim_version)" == "$(stable_nim_version)" ]]
  then
    echo "Nim stable ($(stable_nim_version)) already installed"
    return 0
  fi

  if [[ "$NIM_VERSION" != "devel" \
        && ( "$(installed_nim_version)" == "$NIM_VERSION" \
             || "$(installed_nim_version)" == "v${NIM_VERSION}" ) ]]
  then
    echo "Nim $NIM_VERSION already installed"
    return 0
  fi

  if [[ "$USE_CHOOSENIM" == "yes" ]]
  then
    install_nim_with_choosenim
  else
    # fallback for platforms that don't have choosenim binaries
    install_nim_nightly_or_build_nim
  fi

  add_path "${HOME}/.nimble/bin"
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

init () {
  # Initialize and normalize env vars, then install Nim.

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
    export CHOOSENIM_CHOOSE_VERSION="$NIM_VERSION"
  fi

  export HOST_OS=$(normalize_to_host_os "$(uname)")
  export HOST_CPU=$(normalize_to_host_cpu "$(uname -m)")

  export BIN_EXT=""
  export ZIP_EXT=".tar.xz"

  case $HOST_OS in
    macosx)
      # Work around https://github.com/nim-lang/Nim/issues/12337 fixed in 1.0+
      ulimit -n 8192
      ;;
    windows)
      export BIN_EXT=.exe
      export ZIP_EXT=.zip
      ;;
  esac

  # Autodetect whether to use choosenim or build Nim from source, based on
  # architecture
  if [[ -z "$USE_CHOOSENIM" ]]
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
  if [[ -z "$NIM_PROJECT_DIR" ]]
  then
    local NIMBLE_FILE="$(find . -type f -name "*.nimble" -print \
      | awk '{ print gsub(/\//, "/"), $0 \
      | "sort -n" }' \
      | head -n 1 \
      | sed 's/^[0-9] //')"
    if [[ ! -z "$NIMBLE_FILE" ]]
    then
      export NIM_PROJECT_DIR=$(dirname "$NIMBLE_FILE")
    fi
  fi

  if [[ ! -d "$NIM_PROJECT_DIR" ]]
  then
    echo "Could not find directory containing .nimble file"
    exit 1
  fi

  # Make NIM_PROJECT_DIR absolute
  export NIM_PROJECT_DIR=$(cd "$NIM_PROJECT_DIR"; pwd)

  export NIM_PROJECT_NAME=$(basename \
    $(ls "${NIM_PROJECT_DIR}"/*.nimble \
      | sed -n 's/\(.*\)\.nimble/\1/p'))

  install_nim

  cd "$NIM_PROJECT_DIR"
  export NIM_PROJECT_VERSION=$(nimble dump \
    | grep version: \
    | sed -e 's/version: //g' \
    | sed -e 's/"*//g')
  cd -

  export DIST_DIR="${NIM_PROJECT_DIR}/dist/${NIM_PROJECT_NAME}-${NIM_PROJECT_VERSION}-${HOST_OS}_${HOST_CPU}"
  mkdir -p "$DIST_DIR"

  export ZIP_NAME="${NIM_PROJECT_NAME}-${NIM_PROJECT_VERSION}-${HOST_OS}_${HOST_CPU}${ZIP_EXT}"
  export ZIP_PATH="${NIM_PROJECT_DIR}/dist/${ZIP_NAME}"

  detect_nim_project_type

  if [[ ! -z "$GITHUB_WORKFLOW" ]]
  then
    # Echoing ::set-output makes these variables available in subsequent
    # GitHub Actions steps via
    # ${{ steps.<step-id>.outputs.FOO }}
    # where <step-id> is the YAML id: for the  step that ran this script.
    local DUMP_PREFIX="::set-output name="
  else
    local DUMP_PREFIX=""
  fi

  # Dump config for debugging.
  echo
  echo ">>> nim-ci config >>>"
  echo
  echo "${DUMP_PREFIX}BINS::$(join_string_array ', ' $BINS)"
  echo "${DUMP_PREFIX}BIN_DIR::$BIN_DIR"
  echo "${DUMP_PREFIX}BIN_EXT::$BIN_EXT"
  echo "${DUMP_PREFIX}DIST_DIR::$DIST_DIR"
  echo "${DUMP_PREFIX}HOST_CPU::$HOST_CPU"
  echo "${DUMP_PREFIX}HOST_OS::$HOST_OS"
  echo "${DUMP_PREFIX}NIM_PROJECT_DIR::$NIM_PROJECT_DIR"
  echo "${DUMP_PREFIX}NIM_PROJECT_NAME::$NIM_PROJECT_NAME"
  echo "${DUMP_PREFIX}NIM_PROJECT_TYPE::$NIM_PROJECT_TYPE"
  echo "${DUMP_PREFIX}NIM_VERSION::$NIM_VERSION"
  echo "${DUMP_PREFIX}SRC_DIR::$SRC_DIR"
  echo "${DUMP_PREFIX}USE_CHOOSENIM::$USE_CHOOSENIM"
  echo "${DUMP_PREFIX}ZIP_EXT::$ZIP_EXT"
  echo "${DUMP_PREFIX}ZIP_NAME::$ZIP_NAME"
  echo "${DUMP_PREFIX}ZIP_PATH::$ZIP_PATH"
  echo
  echo "<<< nim-ci config <<<"
  echo
}

init
