#!/bin/bash
echo "Cd into runDriver dir and running zig build run..."
cd "runDriver/"
zig build test
zig build run -DchromeDriverPort=42069 -DchromeDriverExecPath="/Users/matheusduarte/Desktop/browserAutomation-Zig/chromeDriver/chromedriver-mac-x64/chromedriver"
