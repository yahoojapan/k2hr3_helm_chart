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
# Input variables by environment
#----------------------------------------------------------
# K2HR3_NAMESPACE				k2hr3 namespace(ex. "default")
# K2HR3_BASE_DOMAIN				k2hr3 base domain name(ex. "svc.cluster.local")
#
# K2HR3API_COUNT				k2hr3api server(pod) count(ex. 2)
# K2HR3API_LOCAL_BASE_HOSTNAME	k2hr3api base name for hostname(ex. "pod-r3api-dbaask2hr3-")
# K2HR3API_LOCAL_SVC_NAME		k2hr3api service name(ex. "svc-r3api-dbaask2hr3")
# K2HR3API_LOCAL_PORT			k2hr3api local port number(ex. 443)
# K2HR3API_NP_BASE_HOSTNAME		k2hr3api NodePort hostname(ex. "np-r3api-dbaask2hr3")
# K2HR3API_NP_PORT				k2hr3api NodePort port number(ex. 8443)
# 
# K2HR3APP_NP_BASE_HOSTNAME		k2hr3app NodePort hostname(ex. "np-r3app-dbaask2hr3")
# K2HR3APP_NP_PORT				k2hr3api NodePort port number(ex. 8443)
#
PRGNAME=$(basename "$0")
SCRIPTDIR=$(dirname "$0")
SCRIPTDIR=$(cd "${SCRIPTDIR}" || exit 1; pwd)

#----------------------------------------------------------
# Common values
#----------------------------------------------------------
TIMESTAMP=$(date "+%Y-%m-%d-%H:%M:%S")
RESULT_CONTENTS_FILE="/tmp/result-${TIMESTAMP}.log"

#----------------------------------------------------------
# Check enviroment values
#----------------------------------------------------------
if [ -z "${K2HR3_NAMESPACE}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3_NAMESPACE environment is not specified."
	exit 1
fi
if [ -z "${K2HR3_BASE_DOMAIN}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3_BASE_DOMAIN environment is not specified."
	exit 1
fi
if [ -z "${K2HR3API_COUNT}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3API_COUNT environment is not specified."
	exit 1
fi
if [ -z "${K2HR3API_LOCAL_BASE_HOSTNAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3API_LOCAL_BASE_HOSTNAME environment is not specified."
	exit 1
fi
if [ -z "${K2HR3API_LOCAL_SVC_NAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3API_LOCAL_SVC_NAME environment is not specified."
	exit 1
fi
if [ -z "${K2HR3API_LOCAL_PORT}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3API_LOCAL_PORT environment is not specified."
	exit 1
fi
if [ -z "${K2HR3API_NP_BASE_HOSTNAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3API_NP_BASE_HOSTNAME environment is not specified."
	exit 1
fi
if [ -z "${K2HR3API_NP_PORT}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3API_NP_PORT environment is not specified."
	exit 1
fi
if [ -z "${K2HR3APP_NP_BASE_HOSTNAME}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3APP_NP_BASE_HOSTNAME environment is not specified."
	exit 1
fi
if [ -z "${K2HR3APP_NP_PORT}" ]; then
	echo "[ERROR] ${PRGNAME} : K2HR3APP_NP_PORT environment is not specified."
	exit 1
fi

#----------------------------------------------------------
# Check curl command and install
#----------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
	if [ ! -f /etc/os-release ]; then
		echo "[ERROR] Not found /etc/os-release file."
		exit 1
	fi
	OS_NAME=$(grep '^ID[[:space:]]*=[[:space:]]*' /etc/os-release | sed -e 's|^ID[[:space:]]*=[[:space:]]*||g' -e 's|^[[:space:]]*||g' -e 's|[[:space:]]*$||g' -e 's|"||g')

	if echo "${OS_NAME}" | grep -q -i "alpine"; then
		if ! apk update -q --no-progress >/dev/null 2>&1 || ! apk add -q --no-progress --no-cache curl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install curl."
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i "ubuntu"; then
		if env | grep -i -e '^http_proxy' -e '^https_proxy'; then
			if ! test -f /etc/apt/apt.conf.d/00-aptproxy.conf || ! grep -q -e 'Acquire::http::Proxy' -e 'Acquire::https::Proxy' /etc/apt/apt.conf.d/00-aptproxy.conf; then
				_FOUND_HTTP_PROXY=$(env | grep -i '^http_proxy' | head -1 | sed -e 's#^http_proxy=##gi')
				_FOUND_HTTPS_PROXY=$(env | grep -i '^https_proxy' | head -1 | sed -e 's#^https_proxy=##gi')

				if echo "${_FOUND_HTTP_PROXY}" | grep -q -v '://'; then
					_FOUND_HTTP_PROXY="http://${_FOUND_HTTP_PROXY}"
				fi
				if echo "${_FOUND_HTTPS_PROXY}" | grep -q -v '://'; then
					_FOUND_HTTPS_PROXY="http://${_FOUND_HTTPS_PROXY}"
				fi
				if [ ! -d /etc/apt/apt.conf.d ]; then
					mkdir -p /etc/apt/apt.conf.d
				fi
				{
					echo "Acquire::http::Proxy \"${_FOUND_HTTP_PROXY}\";"
					echo "Acquire::https::Proxy \"${_FOUND_HTTPS_PROXY}\";"
				} >> /etc/apt/apt.conf.d/00-aptproxy.conf
			fi
		fi
		DEBIAN_FRONTEND=noninteractive
		export DEBIAN_FRONTEND

		if ! apt-get update -y -q -q >/dev/null 2>&1 || ! apt-get install -y curl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install curl."
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i "centos"; then
		if ! yum update -y -q >/dev/null 2>&1 || ! yum install -y curl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install curl."
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i -e "rocky" -e "fedora"; then
		if ! dnf update -y -q >/dev/null 2>&1 || ! dnf install -y curl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install curl."
			exit 1
		fi
	else
		echo "[ERROR] Unknown OS type(${OS_NAME})."
		exit 1
	fi
fi
CURL_COMMAND=$(command -v curl | tr -d '\n')

#----------------------------------------------------------
# Check K2HR3 API
#----------------------------------------------------------
#
# access to each pod directly
# ex. https://pod-r3api-dbaask2hr3-0.svc-r3api-dbaask2hr3.default.svc.cluster.local:443/
#
while [ "${K2HR3API_COUNT}" -gt 0 ]; do
	K2HR3API_COUNT=$((K2HR3API_COUNT - 1))
	rm -f "${RESULT_CONTENTS_FILE}"

	if ! RESULT_CODE=$("${CURL_COMMAND}" -s -S -w '%{http_code}\n' -o "${RESULT_CONTENTS_FILE}" -X GET https://"${K2HR3API_LOCAL_BASE_HOSTNAME}""${K2HR3API_COUNT}"."${K2HR3API_LOCAL_SVC_NAME}"."${K2HR3_NAMESPACE}"."${K2HR3_BASE_DOMAIN}":"${K2HR3API_LOCAL_PORT}"/ --insecure); then
		echo "[ERROR] ${PRGNAME} : curl command is failed for ${K2HR3API_LOCAL_BASE_HOSTNAME}${K2HR3API_COUNT}.${K2HR3API_LOCAL_SVC_NAME}.${K2HR3_NAMESPACE}.${K2HR3_BASE_DOMAIN}:${K2HR3API_LOCAL_PORT}"
		exit 1
	fi
	if [ -z "${RESULT_CODE}" ] || [ "${RESULT_CODE}" -ne 200 ]; then
		echo "[ERROR] ${PRGNAME} : Got ${RESULT_CODE} http result code from ${K2HR3API_LOCAL_BASE_HOSTNAME}${K2HR3API_COUNT}.${K2HR3API_LOCAL_SVC_NAME}.${K2HR3_NAMESPACE}.${K2HR3_BASE_DOMAIN}:${K2HR3API_LOCAL_PORT}"
		exit 1
	fi

	RESULT_RESPONSE=$(cat "${RESULT_CONTENTS_FILE}")
	if [ -z "${RESULT_RESPONSE}" ] || [ "${RESULT_RESPONSE}" != "{\"version\":[\"v1\"]}" ]; then
		echo "[ERROR] ${PRGNAME} : Got wrong contents( ${RESULT_RESPONSE} ) from ${K2HR3API_LOCAL_BASE_HOSTNAME}${K2HR3API_COUNT}.${K2HR3API_LOCAL_SVC_NAME}.${K2HR3_NAMESPACE}.${K2HR3_BASE_DOMAIN}:${K2HR3API_LOCAL_PORT}"
		exit 1
	fi
done
rm -f "${RESULT_CONTENTS_FILE}"

#
# access to NodePort
# ex. https://np-r3api-dbaask2hr3.default.svc.cluster.local:8443/
#
if ! RESULT_CODE=$("${CURL_COMMAND}" -s -S -w '%{http_code}\n' -o "${RESULT_CONTENTS_FILE}" -X GET https://"${K2HR3API_NP_BASE_HOSTNAME}"."${K2HR3_NAMESPACE}"."${K2HR3_BASE_DOMAIN}":"${K2HR3API_NP_PORT}"/ --insecure); then
	echo "[ERROR] ${PRGNAME} : curl command is failed for ${K2HR3API_NP_BASE_HOSTNAME}.${K2HR3_NAMESPACE}.${K2HR3_BASE_DOMAIN}:${K2HR3API_NP_PORT}"
	exit 1
fi
if [ -z "${RESULT_CODE}" ] || [ "${RESULT_CODE}" -ne 200 ]; then
	echo "[ERROR] ${PRGNAME} : Got ${RESULT_CODE} http result code from ${K2HR3API_NP_BASE_HOSTNAME}.${K2HR3_NAMESPACE}.${K2HR3_BASE_DOMAIN}:${K2HR3API_NP_PORT}"
	exit 1
fi

RESULT_RESPONSE=$(cat "${RESULT_CONTENTS_FILE}")
if [ -z "${RESULT_RESPONSE}" ] || [ "${RESULT_RESPONSE}" != "{\"version\":[\"v1\"]}" ]; then
	echo "[ERROR] ${PRGNAME} : Got wrong contents( ${RESULT_RESPONSE} ) from ${K2HR3API_NP_BASE_HOSTNAME}:${K2HR3API_NP_PORT}"
	exit 1
fi
rm -f "${RESULT_CONTENTS_FILE}"

#----------------------------------------------------------
# Check K2HR3 APP
#----------------------------------------------------------
#
# access to NodePort
# ex. https://np-r3app-dbaask2hr3.default.svc.cluster.local:8443/
#
if ! RESULT_CODE=$("${CURL_COMMAND}" -s -S -w '%{http_code}\n' -o "${RESULT_CONTENTS_FILE}" -X GET https://"${K2HR3APP_NP_BASE_HOSTNAME}"."${K2HR3_NAMESPACE}"."${K2HR3_BASE_DOMAIN}":"${K2HR3APP_NP_PORT}"/ --insecure); then
	echo "[ERROR] ${PRGNAME} : curl command is failed for ${K2HR3APP_NP_BASE_HOSTNAME}.${K2HR3_NAMESPACE}.${K2HR3_BASE_DOMAIN}:${K2HR3APP_NP_PORT}"
	exit 1
fi
if [ -z "${RESULT_CODE}" ] || [ "${RESULT_CODE}" -ne 200 ]; then
	echo "[ERROR] ${PRGNAME} : Got ${RESULT_CODE} http result code from ${K2HR3APP_NP_BASE_HOSTNAME}.${K2HR3_NAMESPACE}.${K2HR3_BASE_DOMAIN}:${K2HR3APP_NP_PORT}"
	exit 1
fi

RESULT_RESPONSE=$(cat "${RESULT_CONTENTS_FILE}")
if [ -z "${RESULT_RESPONSE}" ]; then
	echo "[ERROR] ${PRGNAME} : Got empty contents from ${K2HR3APP_NP_BASE_HOSTNAME}.${K2HR3_NAMESPACE}.${K2HR3_BASE_DOMAIN}:${K2HR3APP_NP_PORT}"
	exit 1
fi
rm -f "${RESULT_CONTENTS_FILE}"

#----------------------------------------------------------
# Finish
#----------------------------------------------------------
echo "[SUCCEED] ${PRGNAME} : No problem to access to K2HR3 API/APP hosts."

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
