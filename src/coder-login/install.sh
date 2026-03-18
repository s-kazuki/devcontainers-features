#!/bin/sh
set -e

if ! command -v coder >/dev/null 2>&1; then
    echo "Coder CLI could not be found. Please ensure it is installed by another feature."
    exit 1
fi

CODER_ENV_PATH=/etc/profile.d/coder-env.sh

> "$CODER_ENV_PATH"
chmod +x "$CODER_ENV_PATH"

env | grep '^CODER' | while IFS='=' read -r key value; do
  echo "export ${key}='${value}'" >> "$CODER_ENV_PATH"
done
env | grep '^GIT' | while IFS='=' read -r key value; do
  echo "export ${key}='${value}'" >> "$CODER_ENV_PATH"
done

coder login --url=${CODER_URL} --token=${CODER_SESSION_TOKEN}