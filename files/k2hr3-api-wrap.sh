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
SLEEP_SHORT=10
SLEEP_LONG_MANUAL=3600000

#----------------------------------------------------------
# Configuration file for CHMPX
#----------------------------------------------------------
INI_FILE="slave.ini"
INI_FILE_PATH="${ANTPICKAX_ETC_DIR}/${INI_FILE}"

#----------------------------------------------------------
# Configuration files for K2HR3 API
#----------------------------------------------------------
K2HR3_API_DIR="/usr/lib/node_modules/k2hr3_api"
RUN_SCRIPT="${K2HR3_API_DIR}/bin/run.sh"
PRODUCTION_FILE="${K2HR3_API_DIR}/config/production.json"
CONFIGMAP_PRODUCTION_FILE="/configmap/k2hr3-api-production.json"

if [ ! -f "${CONFIGMAP_PRODUCTION_FILE}" ]; then
	exit 1
fi

if ! cp "${CONFIGMAP_PRODUCTION_FILE}" "${PRODUCTION_FILE}"; then
	exit 1
fi

#----------------------------------------------------------
# Main processing
#----------------------------------------------------------
#
# Check all hostname
#
ALL_HOST_NAMES=$(grep 'NAME[[:space:]]*=' "${INI_FILE_PATH}" 2>/dev/null | sed 's/^[[:space:]]*NAME[[:space:]]*=[[:space:]]*//g' 2>/dev/null)
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
		_ONE_IP=$(nslookup "${_ONE_NAME}" | grep '[A|a]ddress:' | tail -1 | sed -e 's/^[[:space:]]*[A|a]ddress:[[:space:]]*//g')

		if ! nslookup "${_ONE_IP}" >/dev/null 2>&1; then
			REST_NAMES="${REST_NAMES} ${_ONE_NAME}"
			continue
		fi
		_GET_NAMES=$(nslookup "${_ONE_IP}" | grep 'name[[:space:]]*=' | sed -e 's/^.*[[:space:]]*name[[:space:]]*=[[:space:]]*//g')

		_FIND_NAME_IN_LIST=0
		for _GET_NAME in ${_GET_NAMES}; do
			if [ -n "${_GET_NAME}" ] && [ "${_GET_NAME}" = "${_ONE_NAME}" ]; then
				_FIND_NAME_IN_LIST=1
				break;
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
		if [ "${LOOKUP_RETRYCOUNT}" -gt 0 ]; then
			sleep "${SLEEP_SHORT}"
			LOOKUP_RETRYCOUNT=$((LOOKUP_RETRYCOUNT - 1))
		else
			echo "[ERROR] Lookup hosts is not completed."
			exit 1
		fi
	fi
done

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
	while true; do
		sleep "${SLEEP_LONG_MANUAL}"
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
