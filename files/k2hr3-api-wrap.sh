#!/bin/sh
#
# K2HR3 Helm Chart
#
# Copyright 2022 Yahoo Japan Corporation.
#
# K2HR3 is K2hdkc based Resource and Roles and policy Rules, gathers 
# common management information for the cloud.
# K2HR3 can dynamically manage information as "who", "what", "operate".
# These are stored as roles, resources, policies in K2hdkc, and the
# client system can dynamically read and modify these information.
#
# For the full copyright and license information, please view
# the license file that was distributed with this source code.
#
# AUTHOR:   Takeshi Nakatani
# CREATE:   Wed Jan 19 2022
# REVISION:
#

#----------------------------------------------------------
# Common variables
#----------------------------------------------------------
ANTPICKAX_ETC_DIR="/etc/antpickax"

RETRYCOUNT=30
FILE_RETRYCOUNT=60
SLEEP_SHORT=10
SLEEP_FILE_SHORT=1

#----------------------------------------------------------
# Configuration file for CHMPX
#----------------------------------------------------------
#
# Always k2hr3_api process is on slave node, if not specified mode.
#
K2HR3_CHMPX_MODE="slave"
INI_FILE="${K2HR3_CHMPX_MODE}.ini"
INI_FILE_PATH="${ANTPICKAX_ETC_DIR}/${INI_FILE}"

#----------------------------------------------------------
# Wait configuration file creation
#----------------------------------------------------------
FILE_EXISTS=0
while [ "${FILE_EXISTS}" -eq 0 ]; do
	if [ -f "${INI_FILE_PATH}" ]; then
		FILE_EXISTS=1
	else
		FILE_RETRYCOUNT=$((FILE_RETRYCOUNT - 1))
		if [ "${FILE_RETRYCOUNT}" -le 0 ]; then
			echo "[ERROR] ${INI_FILE_PATH} is not existed."
			exit 1
		fi
		sleep "${SLEEP_FILE_SHORT}"
	fi
done

#----------------------------------------------------------
# Configuration files for K2HR3 API
#----------------------------------------------------------
K2HR3_API_DIR=$(find /usr -type d -name 'k2hr3-api' 2>/dev/null | grep node_modules)
if [ -z "${K2HR3_API_DIR}" ] || [ ! -d "${K2HR3_API_DIR}" ]; then
	K2HR3_API_DIR=$(find /usr -type d -name 'k2hr3_api' 2>/dev/null | grep node_modules)
	if [ -z "${K2HR3_API_DIR}" ] || [ ! -d "${K2HR3_API_DIR}" ]; then
		exit 1
	fi
fi

RUN_SCRIPT="${K2HR3_API_DIR}/bin/run.sh"
PRODUCTION_DIR="${K2HR3_API_DIR}/config"

# [NOTE]
# Configuration files accept json or json5 extensions.
#
PRODUCTION_FILE="${PRODUCTION_DIR}/production.json"
PRODUCTION5_FILE="${PRODUCTION_DIR}/production.json5"
CONFIGMAP_PRODUCTION_FILE="/configmap/k2hr3-api-production.json"
CONFIGMAP_PRODUCTION5_FILE="/configmap/k2hr3-api-production.json5"
LOCAL_FILE="${PRODUCTION_DIR}/local.json"
LOCAL5_FILE="${PRODUCTION_DIR}/local.json5"
CONFIGMAP_LOCAL_FILE="/configmap/k2hr3-api-local.json"
CONFIGMAP_LOCAL5_FILE="/configmap/k2hr3-api-local.json5"

if [ ! -d "${PRODUCTION_DIR}" ]; then
	if ! mkdir -p "${PRODUCTION_DIR}"; then
		exit 1
	fi
fi
if [ -f "${CONFIGMAP_PRODUCTION_FILE}" ]; then
	if ! cp "${CONFIGMAP_PRODUCTION_FILE}" "${PRODUCTION_FILE}"; then
		exit 1
	fi
elif [ -f "${CONFIGMAP_PRODUCTION5_FILE}" ]; then
	if ! cp "${CONFIGMAP_PRODUCTION5_FILE}" "${PRODUCTION5_FILE}"; then
		exit 1
	fi
else
	exit 1
fi
if [ -f "${CONFIGMAP_LOCAL_FILE}" ]; then
	if ! cp "${CONFIGMAP_LOCAL_FILE}" "${LOCAL_FILE}"; then
		exit 1
	fi
elif [ -f "${CONFIGMAP_LOCAL5_FILE}" ]; then
	if ! cp "${CONFIGMAP_LOCAL5_FILE}" "${LOCAL5_FILE}"; then
		exit 1
	fi
fi

#----------------------------------------------------------
# Setup OS_NAME
#----------------------------------------------------------
if [ ! -f /etc/os-release ]; then
	echo "[ERROR] Not found /etc/os-release file."
	exit 1
fi
OS_NAME=$(grep '^ID[[:space:]]*=[[:space:]]*' /etc/os-release | sed -e 's|^ID[[:space:]]*=[[:space:]]*||g' -e 's|^[[:space:]]*||g' -e 's|[[:space:]]*$||g' -e 's|"||g')

if echo "${OS_NAME}" | grep -q -i "centos"; then
	echo "[ERROR] Not support ${OS_NAME}."
	exit 1
fi

#----------------------------------------------------------
# Utility for ubuntu
#----------------------------------------------------------
IS_SETUP_APT_ENV=0

setup_apt_envirnment()
{
	if [ "${IS_SETUP_APT_ENV}" -eq 1 ]; then
		return 0
	fi
	if [ -n "${HTTP_PROXY}" ] || [ -n "${http_proxy}" ] || [ -n "${HTTPS_PROXY}" ] || [ -n "${https_proxy}" ]; then
		if [ ! -f /etc/apt/apt.conf.d/00-aptproxy.conf ] || ! grep -q -e 'Acquire::http::Proxy' -e 'Acquire::https::Proxy' /etc/apt/apt.conf.d/00-aptproxy.conf; then
			_FOUND_HTTP_PROXY=$(if [ -n "${HTTP_PROXY}" ]; then echo "${HTTP_PROXY}"; elif [ -n "${http_proxy}" ]; then echo "${http_proxy}"; else echo ''; fi)
			_FOUND_HTTPS_PROXY=$(if [ -n "${HTTPS_PROXY}" ]; then echo "${HTTPS_PROXY}"; elif [ -n "${https_proxy}" ]; then echo "${https_proxy}"; else echo ''; fi)

			if [ -n "${_FOUND_HTTP_PROXY}" ] && echo "${_FOUND_HTTP_PROXY}" | grep -q -v '://'; then
				_FOUND_HTTP_PROXY="http://${_FOUND_HTTP_PROXY}"
			fi
			if [ -n "${_FOUND_HTTPS_PROXY}" ] && echo "${_FOUND_HTTPS_PROXY}" | grep -q -v '://'; then
				_FOUND_HTTPS_PROXY="http://${_FOUND_HTTPS_PROXY}"
			fi
			if [ ! -d /etc/apt/apt.conf.d ]; then
				mkdir -p /etc/apt/apt.conf.d
			fi
			{
				if [ -n "${_FOUND_HTTP_PROXY}" ]; then
					echo "Acquire::http::Proxy \"${_FOUND_HTTP_PROXY}\";"
				fi
				if [ -n "${_FOUND_HTTPS_PROXY}" ]; then
					echo "Acquire::https::Proxy \"${_FOUND_HTTPS_PROXY}\";"
				fi
			} >> /etc/apt/apt.conf.d/00-aptproxy.conf
		fi
	fi
	DEBIAN_FRONTEND=noninteractive
	export DEBIAN_FRONTEND

	IS_SETUP_APT_ENV=1

	return 0
}

#----------------------------------------------------------
# Preparation
#----------------------------------------------------------
#
# Check and Install nslookup
#
if ! command -v nslookup >/dev/null 2>&1; then
	if echo "${OS_NAME}" | grep -q -i "alpine"; then
		if ! apk update -q --no-progress >/dev/null 2>&1 || ! apk add -q --no-progress --no-cache bind-tools >/dev/null 2>&1; then
			echo "[ERROR] Failed to install bind-tools(nslookup)."
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i -e "ubuntu" -e "debian"; then
		setup_apt_envirnment
		if ! apt-get update -y -q -q >/dev/null 2>&1 || ! apt-get install -y dnsutils >/dev/null 2>&1; then
			echo "[ERROR] Failed to install dnsutils(nslookup)."
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i -e "rocky" -e "fedora"; then
		if ! dnf update -y --nobest --skip-broken -q >/dev/null 2>&1 || ! dnf install -y bind-utils >/dev/null 2>&1; then
			echo "[ERROR] Failed to install bind-utils(nslookup)."
			exit 1
		fi
	else
		echo "[ERROR] Unknown OS type(${OS_NAME})."
		exit 1
	fi
fi

#
# Get all hostname
#
ALL_HOST_NAMES=$(grep 'NAME[[:space:]]*=' "${INI_FILE_PATH}" 2>/dev/null | sed 's/^[[:space:]]*NAME[[:space:]]*=[[:space:]]*//g' 2>/dev/null)

#
# Sleep time ajusting
#
for _ONE_NAME in $(echo "${ALL_HOST_NAMES}" | sort); do
	if echo "${_ONE_NAME}" | grep -q "$(hostname)"; then
		break
	fi
	SLEEP_GAP=$((SLEEP_GAP + 2))
done

#
# Wait all host lookup
#
LOOKUP_RETRYCOUNT="${RETRYCOUNT}"
DONE_ALL_LOOKUP=0
while [ "${DONE_ALL_LOOKUP}" -eq 0 ]; do
	REST_NAMES=""
	for _ONE_NAME in ${ALL_HOST_NAMES}; do
		if [ -z "${_ONE_NAME}" ]; then
			continue
		fi
		if ! nslookup "${_ONE_NAME}" >/dev/null 2>&1; then
			REST_NAMES="${REST_NAMES} ${_ONE_NAME}"
			continue
		fi
		#
		# Get lastest IP address
		#
		_ONE_IP=$(nslookup "${_ONE_NAME}" | grep -i 'address:' | tail -1 | sed -e 's/^[[:space:]]*address:[[:space:]]*//gi')

		if ! nslookup "${_ONE_IP}" >/dev/null 2>&1; then
			REST_NAMES="${REST_NAMES} ${_ONE_NAME}"
			continue
		fi
		_GET_NAMES=$(nslookup "${_ONE_IP}" | grep -i 'name[[:space:]]*=' | sed -e 's/^.*[[:space:]]*name[[:space:]]*=[[:space:]]*//gi')

		_FIND_NAME_IN_LIST=0
		for _GET_NAME in ${_GET_NAMES}; do
			if [ -n "${_GET_NAME}" ]; then
				if [ "${_GET_NAME}" = "${_ONE_NAME}" ] || [ "${_GET_NAME}" = "${_ONE_NAME}." ]; then
					_FIND_NAME_IN_LIST=1
					break;
				fi
			fi
		done
		if [ "${_FIND_NAME_IN_LIST}" -eq 0 ]; then
			REST_NAMES="${REST_NAMES} ${_ONE_NAME}"
		fi
	done

	ALL_HOST_NAMES=${REST_NAMES}

	if [ -z "${ALL_HOST_NAMES}" ]; then
		DONE_ALL_LOOKUP=1
	else
		if [ "${LOOKUP_RETRYCOUNT}" -le 0 ]; then
			echo "[ERROR] Lookup hosts is not completed."
			exit 1
		fi
		sleep "${SLEEP_SHORT}"
		LOOKUP_RETRYCOUNT=$((LOOKUP_RETRYCOUNT - 1))
	fi
done

#----------------------------------------------------------
# Main processing
#----------------------------------------------------------
#
# Wait CHMPX up
#
CHMPX_UP=0
while [ "${CHMPX_UP}" -eq 0 ]; do
	if chmpxstatus -conf "${INI_FILE_PATH}" -self -wait -live up -ring slave -nosuspend -timeout "${SLEEP_SHORT}" >/dev/null 2>&1; then
		CHMPX_UP=1
	else
		sleep "${SLEEP_SHORT}"
		RETRYCOUNT=$((RETRYCOUNT - 1))
		if [ "${RETRYCOUNT}" -le 0 ]; then
			break;
		fi
	fi
done
if [ "${CHMPX_UP}" -eq 0 ]; then
	exit 1
fi
sleep "${SLEEP_SHORT}"

#
# Run K2HR3 API
#
set -e

if [ -n "${K2HR3_MANUAL_START}" ] && [ "${K2HR3_MANUAL_START}" = "true" ]; then
	tail -f /dev/null
else
	"${RUN_SCRIPT}" --production -fg
fi

exit $?

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
