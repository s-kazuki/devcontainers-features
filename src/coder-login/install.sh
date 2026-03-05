#!/bin/sh
set -e

CODER_URL=${CODERURL:-""}
CODER_SESSION_TOKEN=${CODERSESSIONTOKEN:-""}

if ! command -v coder >/dev/null 2>&1; then
    echo "Coder CLI could not be found. Please ensure it is installed by another feature."
    exit 1
fi

coder login --url=${CODER_URL} --token=${CODER_SESSION_TOKEN}