#!/bin/bash

# -----------------------------------------------------------------------------
# Validate Inputs
# -----------------------------------------------------------------------------
if [ -z "$1" ]; then
  echo "The name of the Docker secret to be created must be passed."
  exit 1
elif [ -z "$2" ]; then
  echo "The value to be assigned to the Docker secret must be passed."
  exit 2
fi

DOCKER_SECRET_NAME=$1
DOCKER_SECRET_VALUE=$2

docker secret inspect $DOCKER_SECRET_NAME > /dev/null
if (( $? == 0 )); then
  docker secret rm $DOCKER_SECRET_NAME
fi
echo $DOCKER_SECRET_VALUE | docker secret create $DOCKER_SECRET_NAME -
