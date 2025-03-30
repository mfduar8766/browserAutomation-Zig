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
#  //curl -X POST http://localhost:9515/session/your_session_id/element \
#                 //  -H "Content-Type: application/json" \
#                 //  -d '{
#                 //        "using": "xpath",
#                 //        "value": "//button[@id=\"submit\"]"
#                 //      }'
#                 //
#                 //         curl -X POST http://localhost:9515/session/your_session_id/elements \
#                 //  -H "Content-Type: application/json" \
#                 //  -d '{
#                 //        "using": "xpath",
#                 //        "value": "//div[@class=\"item\"]"
#                 //      }'
#                 //
#                 /// XPath Expression	Description
#                 //button	Selects all <button> elements
#                 //button[@id='submit']	Finds a <button> with id="submit"
#                 //input[@name='username']	Finds an <input> with name="username"
#                 //div[contains(@class, 'card')]	Finds <div> elements that have "card" in the class attribute
#                 //a[text()='Click Me']	Finds an <a> tag with exact text "Click Me"
