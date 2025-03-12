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

RETRYCOUNT=60
SLEEP_SHORT=10

#----------------------------------------------------------
# Configuration files for K2HR3 APP
#----------------------------------------------------------
K2HR3_APP_DIR=$(find /usr -type d -name 'k2hr3-app' 2>/dev/null | grep node_modules)
if [ -z "${K2HR3_APP_DIR}" ] || [ ! -d "${K2HR3_APP_DIR}" ]; then
	K2HR3_APP_DIR=$(find /usr -type d -name 'k2hr3_app' 2>/dev/null | grep node_modules)
	if [ -z "${K2HR3_APP_DIR}" ] || [ ! -d "${K2HR3_APP_DIR}" ]; then
		exit 1
	fi
fi

RUN_SCRIPT="${K2HR3_APP_DIR}/bin/run.sh"
PRODUCTION_DIR="${K2HR3_APP_DIR}/config"

# [NOTE]
# Configuration files accept json or json5 extensions.
#
PRODUCTION_FILE="${PRODUCTION_DIR}/production.json"
PRODUCTION5_FILE="${PRODUCTION_DIR}/production.json5"
TARGET_PRODUCTION_FILE=""
CONFIGMAP_PRODUCTION_FILE="/configmap/k2hr3-app-production.json"
CONFIGMAP_PRODUCTION5_FILE="/configmap/k2hr3-app-production.json5"
TARGET_CONFIGMAP_PRODUCTION_FILE=""
LOCAL_FILE="${PRODUCTION_DIR}/local.json"
LOCAL5_FILE="${PRODUCTION_DIR}/local.json5"
CONFIGMAP_LOCAL_FILE="/configmap/k2hr3-app-local.json"
CONFIGMAP_LOCAL5_FILE="/configmap/k2hr3-app-local.json5"

if [ -f "${CONFIGMAP_PRODUCTION_FILE}" ]; then
	TARGET_PRODUCTION_FILE="${PRODUCTION_FILE}"
	TARGET_CONFIGMAP_PRODUCTION_FILE="${CONFIGMAP_PRODUCTION_FILE}"
elif [ -f "${CONFIGMAP_PRODUCTION5_FILE}" ]; then
	TARGET_PRODUCTION_FILE="${PRODUCTION5_FILE}"
	TARGET_CONFIGMAP_PRODUCTION_FILE="${CONFIGMAP_PRODUCTION5_FILE}"
else
	exit 1
fi

#
# Convert variables:
#	%%K2HR3_APP_EXTERNAL_HOST%%	-> Environment value(usually not effect, it already set.)
#	%%K2HR3_APP_EXTERNAL_PORT%%	-> Environment value or NodePort
#	%%K2HR3_API_EXTERNAL_HOST%%	-> Environment value(usually not effect, it already set.)
#	%%K2HR3_API_EXTERNAL_PORT%%	-> Environment value or NodePort
#
if [ -z "${K2HR3APP_EXTERNAL_PORT}" ] || [ "${K2HR3APP_EXTERNAL_PORT}" = "0" ] ; then
	if [ -z "${K2HR3APP_SERVICE_NAME}" ]; then
		exit 1
	fi
	TMP_APP_NP_NAME=$(echo "${K2HR3APP_SERVICE_NAME}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
	TMP_APP_NP_NAME="${TMP_APP_NP_NAME}_SERVICE_PORT="

	K2HR3APP_EXTERNAL_PORT=$(env | grep "${TMP_APP_NP_NAME}" | sed -e "s/${TMP_APP_NP_NAME}//g")
fi

if [ -z "${K2HR3API_EXTERNAL_PORT}" ] || [ "${K2HR3API_EXTERNAL_PORT}" = "0" ] ; then
	if [ -z "${K2HR3API_SERVICE_NAME}" ]; then
		exit 1
	fi
	TMP_API_NP_NAME=$(echo "${K2HR3API_SERVICE_NAME}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
	TMP_API_NP_NAME="${TMP_API_NP_NAME}_SERVICE_PORT="

	K2HR3API_EXTERNAL_PORT=$(env | grep "${TMP_API_NP_NAME}" | sed -e "s/${TMP_API_NP_NAME}//g")
fi

if [ ! -d "${PRODUCTION_DIR}" ]; then
	if ! mkdir -p "${PRODUCTION_DIR}"; then
		exit 1
	fi
fi

# shellcheck disable=SC2153
if ! sed -e "s#%%K2HR3_APP_EXTERNAL_HOST%%#${K2HR3APP_EXTERNAL_HOST}#g"	\
		-e "s#%%K2HR3_APP_EXTERNAL_PORT%%#${K2HR3APP_EXTERNAL_PORT}#g"	\
		-e "s#%%K2HR3_API_EXTERNAL_HOST%%#${K2HR3API_EXTERNAL_HOST}#g"	\
		-e "s#%%K2HR3_API_EXTERNAL_PORT%%#${K2HR3API_EXTERNAL_PORT}#g"	\
		"${TARGET_CONFIGMAP_PRODUCTION_FILE}"							\
		> "${TARGET_PRODUCTION_FILE}"; then
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
# Certificate files for K2HR3 APP
#----------------------------------------------------------
K2HR3_CA_CERT_ORG_FILE="ca.crt"
K2HR3_CA_CERT_ORG_FILE_PATH="${ANTPICKAX_ETC_DIR}/${K2HR3_CA_CERT_ORG_FILE}"

if [ -f "${K2HR3_CA_CERT_ORG_FILE_PATH}" ]; then
	if echo "${OS_NAME}" | grep -q -i -e "ubuntu" -e "debian"; then
		UPDATE_CA_CERT_BIN="update-ca-certificates"
		UPDATE_CA_CERT_PARAM=""
		SYSTEM_CA_CERT_DIR="/usr/local/share/ca-certificates"

		if ! command -v "${UPDATE_CA_CERT_BIN}" >/dev/null 2>&1; then
			setup_apt_envirnment
			if ! apk-get update -q --no-progress >/dev/null 2>&1 || ! apt-get install -y -q ca-certificates >/dev/null 2>&1; then
				echo "[WARNING] Failed to install ca-certificates package."
			fi
		fi
	elif echo "${OS_NAME}" | grep -q -i -e "rocky" -e "fedora"; then
		UPDATE_CA_CERT_BIN="update-ca-trust"
		UPDATE_CA_CERT_PARAM="extract"
		SYSTEM_CA_CERT_DIR="/etc/pki/ca-trust/source/anchors"

		if ! command -v "${UPDATE_CA_CERT_BIN}" >/dev/null 2>&1; then
			if ! dnf update -y --nobest --skip-broken -q >/dev/null 2>&1 || ! dnf install -y -q ca-certificates >/dev/null 2>&1; then
				echo "[WARNING] Failed to install ca-certificates package."
			fi
		fi
	elif echo "${OS_NAME}" | grep -q -i "alpine"; then
		UPDATE_CA_CERT_BIN="update-ca-certificates"
		UPDATE_CA_CERT_PARAM=""
		SYSTEM_CA_CERT_DIR="/usr/local/share/ca-certificates"

		if ! command -v "${UPDATE_CA_CERT_BIN}" >/dev/null 2>&1; then
			if ! apk update -q --no-progress >/dev/null 2>&1 || ! apk add -q --no-progress --no-cache ca-certificates >/dev/null 2>&1; then
				echo "[WARNING] Failed to install ca-certificates package."
			fi
		fi
	else
		echo "[ERROR] Not support ${OS_NAME}."
		exit 1
	fi
	#
	# Copy CA cert
	#
	if ! cp "${K2HR3_CA_CERT_ORG_FILE_PATH}" "${SYSTEM_CA_CERT_DIR}/${SYSTEM_CA_CERT_K2HR3_FILE}"; then
		echo "[ERROR] ${PRGNAME} : Failed to copy CA certification."
		exit 1
	fi
	#
	# Update CA certs
	#
	if ! /bin/sh -c "${UPDATE_CA_CERT_BIN} ${UPDATE_CA_CERT_PARAM}"; then
		echo "[ERROR] ${PRGNAME} : Failed to update CA certifications."
		exit 1
	fi
fi

#----------------------------------------------------------
# Check curl command and install
#----------------------------------------------------------
if ! CURL_COMMAND=$(command -v curl 2>/dev/null); then
	if echo "${OS_NAME}" | grep -q -i -e "ubuntu" -e "debian"; then
		setup_apt_envirnment
		if ! apt-get update -y -q -q >/dev/null 2>&1 || ! apt-get install -y -q curl >/dev/null 2>&1; then
			echo "[ERROR] ${PRGNAME} : Failed to install curl for ${OS_NAME}."
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i -e "rocky" -e "fedora"; then
		if ! dnf update -y --nobest --skip-broken -q >/dev/null 2>&1 || ! dnf install -y -q curl >/dev/null 2>&1; then
			echo "[ERROR] ${PRGNAME} : Failed to install curl for ${OS_NAME}."
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i "alpine"; then
		if ! apk update -q --no-progress >/dev/null 2>&1 || ! apk add -q --no-progress --no-cache curl >/dev/null 2>&1; then
			echo "[ERROR] ${PRGNAME} : Failed to install curl for ${OS_NAME}."
			exit 1
		fi
	else
		echo "[ERROR] Not support ${OS_NAME}."
		exit 1
	fi

	if ! CURL_COMMAND=$(command -v curl 2>/dev/null); then
		echo "[ERROR] ${PRGNAME} : Could not install curl for ${OS_NAME}."
		exit 1
	fi
fi

#----------------------------------------------------------
# Main processing
#----------------------------------------------------------
#
# Wait for api server up
#
if [ -z "${K2HR3APP_RUN_ON_MINIKUBE}" ] || [ "${K2HR3APP_RUN_ON_MINIKUBE}" != "true" ]; then
	API_SCHEMA=$(grep 'apischeme' "${TARGET_PRODUCTION_FILE}" 2>/dev/null | sed -e "s/['|,]//g" -e 's/^[[:space:]]*apischeme:[[:space:]]*//g' 2>/dev/null)
	API_UP=0
	while [ "${API_UP}" -eq 0 ]; do
		if HTTP_CODE=$("${CURL_COMMAND}" -s -S -w '%{http_code}' -o /dev/null --insecure -X GET "${API_SCHEMA}://${K2HR3API_EXTERNAL_HOST}:${K2HR3API_EXTERNAL_PORT}/" 2>&1); then
			if [ -n "${HTTP_CODE}" ] && [ "${HTTP_CODE}" -eq 200 ]; then
				API_UP=1
			fi
		fi
		if [ "${API_UP}" -ne 1 ]; then
			sleep "${SLEEP_SHORT}"
			RETRYCOUNT=$((RETRYCOUNT - 1))
			if [ "${RETRYCOUNT}" -le 0 ]; then
				break;
			fi
		fi
	done
	if [ "${API_UP}" -eq 0 ]; then
		exit 1
	fi
fi
sleep "${SLEEP_SHORT}"

#
# Run K2HR3 APP
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
