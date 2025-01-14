#!/bin/bash

# Define the screen session title
session_title="chromeDriverSession"

# Kill existing session with the same title if it exists
if screen -ls | grep -q "$session_title"; then
    echo "screen $session_title is running, restarting session"
    screen -S $session_title -X quit
fi

# Start a new screen session with the title 'web_server' and run the command to start the server
screen -dmS $session_title bash -c "chmod +x ./startChromeDriver.sh && ./startChromeDriver.sh; exec bash"
# screen -ls | grep $session_title
# screen -S 18483.web_server -X quit
