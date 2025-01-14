#!/bin/bash

# Define the title you're looking for
session_title="chromeDriverSession"

# Get the session ID by matching the title
session_id=$(screen -ls | grep "$session_title" | awk '{print $1}' | cut -d'.' -f1)

# Check if the session was found
if [ -n "$session_id" ]; then
    echo "Killing screen session: $session_id"
    # Kill the screen session
    screen -S "$session_id" -X quit
else
    echo "No screen session found with title: $session_title"
fi
