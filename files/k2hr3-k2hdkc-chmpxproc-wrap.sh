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
FILE_RETRYCOUNT=60
LOOKUP_RETRYCOUNT=60
SLEEP_SHORT=10

#----------------------------------------------------------
# Make configuration file path
#----------------------------------------------------------
if [ -z "$1" ]; then
	CHMPX_MODE="server"
	SLEEP_GAP=10
elif [ "$1" = "SERVER" ] || [ "$1" = "server" ]; then
	CHMPX_MODE="server"
	SLEEP_GAP=10
elif [ "$1" = "SLAVE" ] || [ "$1" = "slave" ]; then
	CHMPX_MODE="slave"
	SLEEP_GAP=30
else
	CHMPX_MODE="server"
	SLEEP_GAP=10
fi
INI_FILE="${CHMPX_MODE}.ini"
INI_FILE_PATH="${ANTPICKAX_ETC_DIR}/${INI_FILE}"

#----------------------------------------------------------
# Main processing
#----------------------------------------------------------
#
# Wait for creating configuarion file
#
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
		sleep "${SLEEP_SHORT}"
	fi
done

#
# Check all hostname
#
ALL_HOST_NAMES=$(grep 'NAME[[:space:]]*=' "${INI_FILE_PATH}" 2>/dev/null | sed 's/^[[:space:]]*NAME[[:space:]]*=[[:space:]]*//g' 2>/dev/null)
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
sleep "${SLEEP_GAP}"

#
# Run chmpx process
#
set -e

#
# stdio/stderr is not redirected.
#
chmpx -conf "${INI_FILE_PATH}" -d err

exit $?

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
