#!/bin/bash

echo "Cd into runDriver dir and running zig build run.."
cd "runDriver/"
zig build test
exec zig build run -DchromeDriverPort=42069 -DchromeDriverExecPath=chromeDriver/chromedriver-mac-x64/chromedriver &

