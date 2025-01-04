#!/bin/bash

$buildType=$0;
RELEASE_SMALL="ReleaseSmall"
RELEASE_SAFE="ReleaseSafe"
RELEASE_FAST="ReleaseFast"
RELEASE_DEBUG="Debug"

cd "automation/" &

if [ -z "$buildType"]; then
  $buildType = "-Doptimize $RELEASE_SAFE";
elif ["$buildType" == "rs"]; then
  $buildType = "-Doptimize $RELEASE_SMALL";
else if ["$buildType" == "rf"]; then
  $buildType = "-Doptimize $RELEASE_FAST";
else if ["$buildType" == "d"]; then
  $buildType = "-Doptimize $RELEASE_DEBUG";
fi

zig build test --summary all &
zig build $buildType run --summary all
