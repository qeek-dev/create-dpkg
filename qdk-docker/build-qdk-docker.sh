#!/bin/bash

# basic information
SCRIPT_PATH="$(dirname $(realpath $BASH_SOURCE))"


# QDK in the docker
QDK_DOCKER_USERNAME=$1
QDK_DOCKER_NAME=$2
QDK_DOCKER_VERSION=$3
QDK_DOKCER_IMAGE="${QDK_DOCKER_USERNAME}/${QDK_DOCKER_NAME}:${QDK_DOCKER_VERSION}"


# log text with color in the terminal
RED=`tput setaf 1`
RESET=`tput sgr0`

function log_err_exit() {
	echo "${RED} [X] [$(date '+%Y/%m/%d %H:%M:%S')] $@ ${RESET}"
	exit 1
}

check_command() {
	command -v $1 >/dev/null 2>&1 || log_err_exit "Require \"$1\" but it's not installed.  Aborting."
}


check_command docker

# build the qdk docker image if it dose not exist
if [[ "$(docker images -q ${QDK_DOKCER_IMAGE} 2>/dev/null)" == "" ]]; then
	# the run time qdk docker image
	docker build \
		-t "${QDK_DOKCER_IMAGE}" \
		"${SCRIPT_PATH}"
fi
