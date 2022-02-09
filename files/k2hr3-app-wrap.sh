#!/bin/sh
#
# K2HR3 Helm Chart
#
# Copyright 2022 Yahoo! Japan Corporation.
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
#PRGNAME=$(basename "$0")
#SCRIPTDIR=$(dirname "$0")
#SCRIPTDIR=$(cd "${SRCTOP}" || exit 1; pwd)

ANTPICKAX_ETC_DIR="/etc/antpickax"

RETRYCOUNT=60
SLEEP_SHORT=10
SLEEP_LONG_MANUAL=3600000

#----------------------------------------------------------
# Configuration files for K2HR3 APP
#----------------------------------------------------------
K2HR3_APP_DIR="/usr/lib/node_modules/k2hr3_app"
RUN_SCRIPT="${K2HR3_APP_DIR}/bin/run.sh"
PRODUCTION_FILE="${K2HR3_APP_DIR}/config/production.json"
CONFIGMAP_PRODUCTION_FILE="/configmap/k2hr3-app-production.json"

if [ ! -f "${CONFIGMAP_PRODUCTION_FILE}" ]; then
	exit 1
fi

#
# Convert variables:
#	%%K2HR3_APP_EXTERNAL_HOST%%	-> Environment value(usually not effect, it already set.)
#	%%K2HR3_APP_EXTERNAL_PORT%%	-> Environment value or NodePort
#	%%K2HR3_API_EXTERNAL_HOST%%	-> Environment value(usually not effect, it already set.)
#	%%K2HR3_API_EXTERNAL_PORT%%	-> Environment value or NodePort
#
if [ -z "${K2HR3APP_EXTERNAL_PORT}" ] || [ "X${K2HR3APP_EXTERNAL_PORT}" = "X0" ] ; then
	if [ -z "${K2HR3APP_SERVICE_NAME}" ]; then
		exit 1
	fi
	TMP_APP_NP_NAME=$(echo "${K2HR3APP_SERVICE_NAME}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
	TMP_APP_NP_NAME="${TMP_APP_NP_NAME}_SERVICE_PORT="

	K2HR3APP_EXTERNAL_PORT=$(env | grep "${TMP_APP_NP_NAME}" | sed -e "s/${TMP_APP_NP_NAME}//g" | tr -d '\n')
fi

if [ -z "${K2HR3API_EXTERNAL_PORT}" ] || [ "X${K2HR3API_EXTERNAL_PORT}" = "X0" ] ; then
	if [ -z "${K2HR3API_SERVICE_NAME}" ]; then
		exit 1
	fi
	TMP_API_NP_NAME=$(echo "${K2HR3API_SERVICE_NAME}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
	TMP_API_NP_NAME="${TMP_API_NP_NAME}_SERVICE_PORT="

	K2HR3API_EXTERNAL_PORT=$(env | grep "${TMP_API_NP_NAME}" | sed -e "s/${TMP_API_NP_NAME}//g" | tr -d '\n')
fi

# shellcheck disable=SC2153
sed	-e "s#%%K2HR3_APP_EXTERNAL_HOST%%#${K2HR3APP_EXTERNAL_HOST}#g"	\
	-e "s#%%K2HR3_APP_EXTERNAL_PORT%%#${K2HR3APP_EXTERNAL_PORT}#g"	\
	-e "s#%%K2HR3_API_EXTERNAL_HOST%%#${K2HR3API_EXTERNAL_HOST}#g"	\
	-e "s#%%K2HR3_API_EXTERNAL_PORT%%#${K2HR3API_EXTERNAL_PORT}#g"	\
	< "${CONFIGMAP_PRODUCTION_FILE}" \
	> "${PRODUCTION_FILE}"

if [ $? -ne 0 ]; then
	exit 1
fi

#----------------------------------------------------------
# Certificate files for K2HR3 APP
#----------------------------------------------------------
K2HR3_CA_CERT_ORG_FILE="ca.crt"
K2HR3_CA_CERT_ORG_FILE_PATH="${ANTPICKAX_ETC_DIR}/${K2HR3_CA_CERT_ORG_FILE}"

SYSTEM_CA_CERT_DIR="/usr/local/share/ca-certificates"
SYSTEM_CA_CERT_K2HR3_FILE="k2hr3-system-ca.crt"
SYSTEM_CA_CERT_K2HR3_FILE_PATH="${SYSTEM_CA_CERT_DIR}/${SYSTEM_CA_CERT_K2HR3_FILE}"

if [ -f "${K2HR3_CA_CERT_ORG_FILE_PATH}" ]; then
	cp "${K2HR3_CA_CERT_ORG_FILE_PATH}" "${SYSTEM_CA_CERT_K2HR3_FILE_PATH}"
	if [ $? -ne 0 ]; then
		exit 1
	fi

	update-ca-certificates
	if [ $? -ne 0 ]; then
		exit 1
	fi
fi

#----------------------------------------------------------
# Check curl command and install
#----------------------------------------------------------
CURL_COMMAND=$(command -v curl | tr -d '\n')
if [ $? -ne 0 ] || [ -z "${CURL_COMMAND}" ]; then
	APK_COMMAND=$(command -v apk | tr -d '\n')
	if [ $? -ne 0 ] || [ -z "${APK_COMMAND}" ]; then
		echo "[ERROR] ${PRGNAME} : This container it not ALPINE, It does not support installations other than ALPINE, so exit."
		exit 1
	fi
	${APK_COMMAND} add -q --no-progress --no-cache curl
	if [ $? -ne 0 ]; then
		echo "[ERROR] ${PRGNAME} : Failed to install curl by apk(ALPINE)."
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
	API_SCHEMA=$(grep 'apischeme' "${PRODUCTION_FILE}" 2>/dev/null | sed -e "s/['|,]//g" -e 's/^[[:space:]]*apischeme:[[:space:]]*//g' 2>/dev/null | tr -d '\n')
	API_UP=0
	while [ "${API_UP}" -eq 0 ]; do
		HTTP_CODE=$(curl -s -S -w '%{http_code}\n' -o /dev/null --insecure -X GET "${API_SCHEMA}://${K2HR3API_EXTERNAL_HOST}:${K2HR3API_EXTERNAL_PORT}/" 2>&1)
		if [ $? -eq 0 ] && [ "${HTTP_CODE}" -eq 200 ]; then
			API_UP=1
		else
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

if [ "X${K2HR3_MANUAL_START}" = "Xtrue" ]; then
	while true; do
		sleep ${SLEEP_LONG_MANUAL}
	done
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
