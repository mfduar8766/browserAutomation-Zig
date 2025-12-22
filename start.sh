#!/bin/bash

BUILD_TYPE=$0;
RELEASE_DEBUG="Debug"
RELEASE_SAFE="ReleaseSafe"
RELEASE_FAST="ReleaseFast"
RELEASE_SMALL="ReleaseSmall"
ZIG_RELEASE_MODE="-DreleaseType=$RELEASE_SAFE"
ZIG_BUILD_AND_TEST="zig build run $ZIG_RELEASE_MODE"
OS=$(uname)
RUN_EXAMPLE_UI=$1;
RUN_AUTOMATION=$3;

if [[ "$OS" == "Darwin" ]]; then
    echo "This is macOS."
elif [[ "$OS" == "Linux" ]]; then
    if command -v screen &> /dev/null; then
      echo "screen is installed"
    else
      echo "This is Linux. You need to install the screen package to continue."
      echo "Please run the appropriate command to install screen pkg on your distro and re run the ./start.sh script"
      exit 0
    fi
elif [[ "$OS" == "MINGW"* ]] || [[ "$OS" == "MSYS"* ]]; then
    echo "This is Windows. You need to run this under WSL to use this app."
    exit 0
else
    echo "Unknown OS."
fi

setReleaseMode() {
  if [[ "$BUILD_TYPE" == "0" ]]; then
    ZIG_RELEASE_MODE = "-DreleaseType=$RELEASE_DEBUG"
  elif [[ "$BUILD_TYPE" == "1" ]]; then
    ZIG_RELEASE_MODE = "-DreleaseType=$RELEASE_SAFE"
  elif [[ "$BUILD_TYPE" == "2" ]]; then 
    ZIG_RELEASE_MODE = "-DreleaseType=$RELEASE_FAST"
  elif [[ "$BUILD_TYPE" == "3" ]]; then
    ZIG_RELEASE_MODE = "-DreleaseType=$RELEASE_SMALL"
  else
    echo "No release optimization specified using $ZIG_RELEASE_MODE"
  fi
}

if [ "$RUN_EXAMPLE_UI" == "y" ]; then
  cd example/
  setReleaseMode
  echo "Running command: $ZIG_BUILD_AND_TEST";
  $ZIG_BUILD_AND_TEST
elif [ "$RUN_AUTOMATION" == "Y" ]; then
  cd automation/
  setReleaseMode
  $ZIG_BUILD_AND_TEST
fi
