#!/bin/bash

# ------------------------------------------------------------------------------
# Basic information
# ------------------------------------------------------------------------------
SCRIPT_PATH="$(dirname $(realpath ${BASH_SOURCE}))"
QDK_SOURCE="${SCRIPT_PATH}/qdk-docker/QDK"


# ------------------------------------------------------------------------------
# QDK docker information
# ------------------------------------------------------------------------------
QDK_DOCKER_USERNAME=qeekdev
QDK_DOCKER_NAME=qdk-docker
QDK_DOCKER_VERSION=latest
QDK_DOKCER_IMAGE="${QDK_DOCKER_USERNAME}/${QDK_DOCKER_NAME}:${QDK_DOCKER_VERSION}"


# ------------------------------------------------------------------------------
# QPKG information
# ------------------------------------------------------------------------------
QPKG_NAME="create-qpkg"
WORKSPACE="${SCRIPT_PATH}/workspace"
WORKSPACE_QDK_ROOT="${WORKSPACE}/QDK"
WORKSPACE_QPKG_ROOT="${WORKSPACE_QDK_ROOT}/${QPKG_NAME}"
RELEASE="${SCRIPT_PATH}/release"


# ------------------------------------------------------------------------------
# Log functions
# ------------------------------------------------------------------------------
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
MAGENTA=`tput setaf 5`
RESET=`tput sgr0`

log() {
	echo "${GREEN} [V] [$(date '+%Y/%m/%d %H:%M:%S')] $@ ${RESET}"
}

log_info() {
	echo "${YELLOW} [I] [$(date '+%Y/%m/%d %H:%M:%S')] $@ ${RESET}"
}

log_err() {
	echo "${RED} [X] [$(date '+%Y/%m/%d %H:%M:%S')] $@ ${RESET}"
}

log_warn() {
	echo "${MAGENTA} [W] [$(date '+%Y/%m/%d %H:%M:%S')] $@ ${RESET}"
}

log_err_exit() {
	echo "${RED} [X] [$(date '+%Y/%m/%d %H:%M:%S')] $@ ${RESET}"
	exit 1
}

check_command() {
	command -v ${1} >/dev/null 2>&1 || log_err_exit "Require \"${1}\" but it's not installed.  Aborted"
}

exec_err() {
	"$@"	  # execute the command
	STATUS=$? # get status of execution
	if [ $STATUS -ne 0 ]; then
		log_err "ERROR: Encountered error (${STATUS}) while running the following:" >&2
		log_err "           $@"  >&2
		log_err "       (at line ${BASH_LINENO[0]} of file $(realpath ${BASH_SOURCE}))"  >&2
		log_err "       Aborted" >&2
		exit $status
	fi
}


# ------------------------------------------------------------------------------
# Prepare workspace for building QPKG
# ------------------------------------------------------------------------------
init_workspace() {
	log "[ ${FUNCNAME} ] (1/3) Clear workspace"
	[ ! -d ${WORKSPACE} ] && exec_err mkdir -p "${WORKSPACE}"
	[ ! -d ${RELEASE} ] && exec_err mkdir -p "${RELEASE}"

	rm -rf "${WORKSPACE_QDK_ROOT}" >/dev/null 2>&1
	rm -rf "${WORKSPACE_QPKG_ROOT}" >/dev/null 2>&1

	log "[ ${FUNCNAME} ] (2/3) Prepare QKD"
	exec_err mkdir -p "${WORKSPACE_QDK_ROOT}"
	exec_err cp -r "${QDK_SOURCE}/shared/." "${WORKSPACE_QDK_ROOT}"

	log "[ ${FUNCNAME} ] (3/3) Prepare QPKG template"
	exec_err mkdir -p "${WORKSPACE_QPKG_ROOT}"
	exec_err cp -r "${QDK_SOURCE}/shared/template/." "${WORKSPACE_QPKG_ROOT}"
}


# ------------------------------------------------------------------------------
# Build user own program and organize built files well for QPKG.
# In this function, you can call your own scripts or just organize your pre-
# built files.
# ------------------------------------------------------------------------------
build_source() {
	log "[ ${FUNCNAME} ] (1/2) Prepare start scripts"
	exec_err cp -r "${SCRIPT_PATH}/src/init.d/." "${WORKSPACE_QPKG_ROOT}/shared"

	log "[ ${FUNCNAME} ] (2/2) Prepare asset"
	exec_err cp -r "${SCRIPT_PATH}/src/asset/." "${WORKSPACE_QPKG_ROOT}/"

	log_warn "[ ${FUNCNAME} ] Add your own script [ HERE ]"
	# --------------------------------------------------------------------------
	# [HERE] You will add the scrpit that builds your source code and places the
  	# program at right place. 
	#
	# For example:
	# log "[ ${FUNCNAME} ] (3/4) Prepare server"
	# build_backend_server
	# exec_err cp "${SCRIPT_PATH}/src/server/start_server" "${WORKSPACE_QPKG_ROOT}/shared"
	#
	# log "[ ${FUNCNAME} ] (4/4) Prepare web page"
	# build_web_client
	# exec_err cp -r "${SCRIPT_PATH}/src/web-client/build" "${WORKSPACE_QPKG_ROOT}/shared/web"
	# --------------------------------------------------------------------------
}


# ------------------------------------------------------------------------------
# Build the QPKG with QDK container. Name the QPKG with the number of build and
# the time.
# ------------------------------------------------------------------------------
build_qpkg() {
	log "[ ${FUNCNAME} ] (1/2) Configure building"
	cd "${SCRIPT_PATH}"
	local BUILD_COUNT=`git rev-list HEAD --count`
	local BUILD_REVISION="${BUILD_COUNT}"

	# save source code revision and arch into qpkg
	echo -n "${BUILD_REVISION}" > "${WORKSPACE_QPKG_ROOT}/shared/.revision"
	echo -n "${CPU_ARCH}" > "${WORKSPACE_QPKG_ROOT}/shared/.qpkg_arch"

	local BUILD_DATE=`date +"%Y%m%d%H%M"`
	local QPKG_FILE="${QPKG_NAME}_${QPKG_VERSION}_${CPU_ARCH}_${BUILD_DATE}"
	local CONTAINER_NAME=${QDK_DOCKER_NAME}-`date +%s`
	local BUILDER_OPTS=" \
		--net=host \
		--rm \
		-e \"TZ=Asia/Taipei\" \
		-u root \
		-w /root \
		-v ${SCRIPT_PATH}:/root/tmp \
		--name=${CONTAINER_NAME}"

	log "[ ${FUNCNAME} ] (2/2) Build QPKG in QDK container"
	docker run ${BUILDER_OPTS} ${QDK_DOKCER_IMAGE} /bin/bash -c "\
		qbuild -v \
		--root /root/tmp/workspace/QDK/${QPKG_NAME} \
		--build-arch ${CPU_ARCH} \
		--build-version ${QPKG_VERSION} && \
		mv /root/tmp/workspace/QDK/${QPKG_NAME}/build/*.qpkg /root/tmp/release/${QPKG_FILE}.qpkg && \
		mv /root/tmp/workspace/QDK/${QPKG_NAME}/build/*.qpkg.md5 /root/tmp/release/${QPKG_FILE}.qpkg.md5 \
		"

	[ $? != "0" ] && log_err_exit "[ ${FUNCNAME} ] Failed"
	log_info "[ QPKG Build SUCCESS ]"
	log_info "	=> ${RELEASE}/${QPKG_FILE}.qpkg"
	log_info "	=> ${RELEASE}/${QPKG_FILE}.qpkg.md5"
}


# ------------------------------------------------------------------------------
# Install the latest QPKG to remote NAS
# ------------------------------------------------------------------------------
install_latest_qpkg() {
	# get latest qpkg file by modify time.
	local QPKG_FILE=`ls ${RELEASE}/*${CPU_ARCH}*.qpkg | sort -r | head -1`
	local SSHPASS_CMD="sshpass -p ${REMOTE_PASSWD}"

	[ ! -f ${QPKG_FILE} ] && log_err_exit "QPKG NOT FOUND"

	log "[ ${FUNCNAME} ] (1/2) Copy file to remote NAS"
	"${SSHPASS_CMD} scp" \
		"-o StrictHostKeyChecking=no" \
		"-o UserKnownHostsFile=/dev/null" \
		"${QPKG_FILE}" \
		"admin@${REMOTE_HOST}:/share/Public/${QPKG_NAME}" \
		>/dev/null 2>&1
	[ $? != "0" ] && log_err_exit "[ ${FUNCNAME} ] Failed"

	log "[ ${FUNCNAME} ] (2/2) Install on remote NAS"
	"${SSHPASS_CMD} ssh" \
		"-o StrictHostKeyChecking=no" \
		"-o UserKnownHostsFile=/dev/null" \
		"-t admin@${REMOTE_HOST}" \
		"export LANG=en_US.UTF-8; \
		export LC_ALL=en_US.UTF-8; \
		export LANGUAGE=en_US.UTF-8; \
		qpkg_cli -D 2 -m /share/Public/${QPKG_NAME}; \
		sleep 3" \
		>/dev/null 2>&1

	[ $? != "0" ] && log_err_exit "[ ${FUNCNAME} ] Failed"
	log_info "Installation SUCCESS at ${REMOTE_HOST}"
}


# ------------------------------------------------------------------------------
# Chech basic prerequisite for building QPKG, including the commands and the QDK
# docekr image.
# ------------------------------------------------------------------------------
check_prerequisite() {
	COMMANDS=('docker' 'git' 'ssh' 'scp' 'sshpass')
	log "[ ${FUNCNAME} ] (1/3) Check commands: ${COMMANDS[@]}"
	for CMD in "${COMMANDS[@]}"; do
		check_command "${CMD}"
	done

	log "[ ${FUNCNAME} ] (2/3) QDK repo"
	git submodule update --init qdk-docker/QDK

	log "[ ${FUNCNAME} ] (3/3) Check QDK container"
	${SCRIPT_PATH}/qdk-docker/build-qdk-docker.sh \
		"${QDK_DOCKER_USERNAME}" \
		"${QDK_DOCKER_NAME}" \
		"${QDK_DOCKER_VERSION}"
}


# ------------------------------------------------------------------------------
# Entry point of this script that builds QPKG (and install to remote NAS).
# The arguments are:
# 1. CPU_ARCH: 		Target CPU architecture
# 2. QPKG_VERSION: 	QPKG version of this build
# 3. REMOTE_HOST: 	IP of NAS to install after building
# 4. REMOTE_PASSWD: Password of NAS to install after building
# ------------------------------------------------------------------------------
if [ $# -ne 2 ] && [ $# -ne 4 ]; then
	echo ''
	echo "${0} {CPU_ARCH} {QPKG_VERSION} [{REMOTE_HOST} {REMOTE_PASSWD}]"
	echo '1.      CPU_ARCH: Target CPU architecture (x86_64, arm_64, arm-x41, arm-x31, ...)'
	echo '2.  QPKG_VERSION: QPKG version of this build'
	echo '3.   REMOTE_HOST: IP of NAS to install after building'
	echo '4. REMOTE_PASSWD: Password of NAS to install after building'
	echo ''
	echo 'Example (1) build QPKG only'
	echo "${0} x86_64 1.0.0"
	echo 'Example (2) build QPKG and install to remote NAS'
	echo "${0} x86_64 1.0.0 {IP} {admin_password}"
	echo ''
	exit 1
fi

# Parse arugments
CPU_ARCH=${1}
QPKG_VERSION=${2}
REMOTE_HOST=${3}
REMOTE_PASSWD=${4}

log_info ""
log_info "*** CONFIGURATIONS: ***"
log_info "1.      CPU_ARCH: ${CPU_ARCH}"
log_info "2.  QPKG_VERSION: ${QPKG_NAME}"
log_info "3.   REMOTE_HOST: ${REMOTE_HOST}"
log_info "4. REMOTE_PASSWD: ${REMOTE_PASSWD}"


log_info ""
log_info "*** CHECKING PREREQUISITE START    ***"
check_prerequisite
log_info "*** CHECKING PREREQUISITE FINISHED ***"


log_info ""
log_info "*** BUILDING ${QPKG_NAME} QPKG for ${CPU_ARCH} START    ***"
init_workspace
build_source
build_qpkg
log_info "*** BUILDING ${QPKG_NAME} QPKG for ${CPU_ARCH} FINISHED ***"


log_info ""
if [ -z ${REMOTE_HOST} ] && [ -z ${REMOTE_PASSWD} ]; then
	log_warn '*** SKIP INSTALLATION SINCE $REMOTE_HOST IS UNDEFINED ***'
else
	log_info "*** INSTALLING QPKG TO $REMOTE_HOST START    ***"
	install_latest_qpkg
	log_info "*** INSTALLING QPKG TO $REMOTE_HOST FINISHED ***"
fi
