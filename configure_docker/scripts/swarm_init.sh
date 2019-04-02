#!/bin/bash

set -eou pipefail

# -----------------------------------------------------------------------------
# Validate Inputs
# -----------------------------------------------------------------------------
if [ -z "$1" ]; then
  echo "The base Docker hostname is required as the first argument."
  exit 1
elif [ -z "$2" ]; then
  echo "The number of Docker servers is required as the second argument."
  exit 2
elif ! [[ $2 =~ ^[0-9]+$ ]]; then
  echo "The number of Docker servers must be a numeric value."
  exit 3
elif [ $2 -lt 1 ]; then
  echo "The number of Docker servers must be greater than zero."
  exit 4
fi

DOCKER_BASE_HOSTNAME=$1
DOCKER_SERVER_COUNT=$2

# -----------------------------------------------------------------------------
#  Registers Both Swarm Managers and Workers Based Upon JOIN_TOKEN
# -----------------------------------------------------------------------------
register_server() {
  ROLE=$1
  SERVER_HOSTNAME=$2
  LEADER_HOSTNAME=$3
  JOIN_TOKEN=$4

  echo Checking $ROLE Registration: $SERVER_HOSTNAME
  REGISTERED=$(sudo salt $LEADER_HOSTNAME* cmd.run 'sudo docker node ls' | grep $SERVER_HOSTNAME) || REGISTERED=
  echo Error Code: $?
  if [ -z "$REGISTERED" ]; then
    echo Registering $ROLE: $SERVER_HOSTNAME
    sudo salt $SERVER_HOSTNAME* cmd.run "sudo docker swarm join --token $JOIN_TOKEN"
  else
    echo Validated $ROLE Registration: $SERVER_HOSTNAME
  fi
}

# -----------------------------------------------------------------------------
# Main Loop
# -----------------------------------------------------------------------------
for (( CURRENT = 1; CURRENT <= $DOCKER_SERVER_COUNT; CURRENT++ ))
do
  CURRENT_HOSTNAME=$(printf "$DOCKER_BASE_HOSTNAME-%02d" $CURRENT)
  if [ $CURRENT -eq 1 ]; then
    LEADER_HOSTNAME=$CURRENT_HOSTNAME
    echo Checking Manager Registration: $LEADER_HOSTNAME
    WORKER_JOIN_TOKEN=$(sudo salt $LEADER_HOSTNAME* cmd.run 'sudo docker swarm join-token worker' | grep -o 'SWMTKN.*') || WORKER_JOIN_TOKEN=
    if [ -z "$WORKER_JOIN_TOKEN" ]; then
      echo Registering Manager: $LEADER_HOSTNAME
      WORKER_JOIN_TOKEN=$(sudo salt $LEADER_HOSTNAME* cmd.run 'sudo docker swarm init' | grep -o 'SWMTKN.*')
      if [ -z "$WORKER_JOIN_TOKEN" ]; then
        echo "Unable to obtain a worker join token."
        exit 5
      fi
    else
      echo Validated Manager Registration: $LEADER_HOSTNAME
    fi
    MANAGER_JOIN_TOKEN=$(sudo salt $LEADER_HOSTNAME* cmd.run 'sudo docker swarm join-token manager' | grep -o 'SWMTKN.*')
    if [ -z "$MANAGER_JOIN_TOKEN" ]; then
      echo "Unable to obtain a manager join token."
      exit 6
    fi
  elif [ $CURRENT -lt 4 ]; then
    register_server 'Manager' $CURRENT_HOSTNAME $LEADER_HOSTNAME "$MANAGER_JOIN_TOKEN"
  else
    register_server 'Worker' $CURRENT_HOSTNAME $LEADER_HOSTNAME "$WORKER_JOIN_TOKEN"
  fi
done
