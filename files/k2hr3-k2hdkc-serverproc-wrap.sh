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
PRGNAME=$(basename "$0")
SCRIPTDIR=$(dirname "$0")
SCRIPTDIR=$(cd "${SCRIPTDIR}" || exit 1; pwd)

ANTPICKAX_ETC_DIR="/etc/antpickax"
ANTPICKAX_RUN_DIR="/var/run/antpickax"

WATCHER_SERVICEIN_FILE="k2hkdc_servicein.cmd"
WATCHER_SERVICEIN_FILE_PATH="${ANTPICKAX_RUN_DIR}/${WATCHER_SERVICEIN_FILE}"
WATCHER_RECOVER_FILE="k2hkdc_recover.cmd"
WATCHER_RECOVER_FILE_PATH="${ANTPICKAX_RUN_DIR}/${WATCHER_RECOVER_FILE}"
WATCHER_STSUPDATE_FILE="k2hkdc_statusupdate.cmd"
WATCHER_STSUPDATE_FILE_PATH="${ANTPICKAX_RUN_DIR}/${WATCHER_STSUPDATE_FILE}"

WATCHER_OPT="-watcher"
RETRYCOUNT=60
SLEEP_LONG=20
SLEEP_MIDDLE=10
SLEEP_SHORT=1

#----------------------------------------------------------
# Make configuration file path
#----------------------------------------------------------
#
# Always k2hdkc process is on server node, if not specified mode.
#
K2HDDKC_MODE="server"
INI_FILE="${K2HDDKC_MODE}.ini"
INI_FILE_PATH="${ANTPICKAX_ETC_DIR}/${INI_FILE}"

#----------------------------------------------------------
# Main processing
#----------------------------------------------------------
if [ "X$1" = "X${WATCHER_OPT}" ]; then
	#
	# Run watcher
	#
	LOCALHOSTNAME=$(chmpxstatus -conf "${INI_FILE_PATH}" -self	| grep 'hostname'		| sed -e 's/[[:space:]]*$//g' -e 's/^[[:space:]]*hostname[[:space:]]*=[[:space:]]*//g')
	CTLPORT=$(chmpxstatus -conf "${INI_FILE_PATH}" -self		| grep 'control port'	| sed -e 's/[[:space:]]*$//g' -e 's/^[[:space:]]*control port[[:space:]]*=[[:space:]]*//g')
	CUK=$(chmpxstatus -conf "${INI_FILE_PATH}" -self			| grep 'cuk'			| sed -e 's/[[:space:]]*$//g' -e 's/^[[:space:]]*cuk[[:space:]]*=[[:space:]]*//g')
	CUSTOM_SEED=$(chmpxstatus -conf "${INI_FILE_PATH}" -self	| grep 'custom id seed'	| sed -e 's/[[:space:]]*$//g' -e 's/^[[:space:]]*custom id seed[[:space:]]*=[[:space:]]*//g')

	{
		echo "servicein ${LOCALHOSTNAME}:${CTLPORT}:${CUK}:${CUSTOM_SEED}:"
		echo "sleep ${SLEEP_SHORT}"
		echo "statusupdate"
		echo "exit"
	} > "${WATCHER_SERVICEIN_FILE_PATH}"
	{
		echo "serviceout ${LOCALHOSTNAME}:${CTLPORT}:${CUK}:${CUSTOM_SEED}:"
		echo "sleep ${SLEEP_SHORT}"
		echo "statusupdate"
		echo "exit"
	} > "${WATCHER_RECOVER_FILE_PATH}"
	{
		echo "statusupdate"
		echo "exit"
	} > ${WATCHER_STSUPDATE_FILE_PATH}

	LOOP_BREAK=0
	while [ "${LOOP_BREAK}" -eq 0 ]; do
		chmpxstatus -conf "${INI_FILE_PATH}" -self -wait -live up -ring servicein -nosuspend -timeout "${SLEEP_SHORT}" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			chmpxstatus -conf "${INI_FILE_PATH}" -self | grep 'status[[:space:]]*=' | grep '\[ADD\]' | grep '\[Pending\]' >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				# 
				# When the status is "ADD:Pending", type a new ServiceIn command after short sleep.
				#
				sleep ${SLEEP_MIDDLE}
				chmpxstatus -conf "${INI_FILE_PATH}" -self | grep 'status[[:space:]]*=' | grep '\[ADD\]' | grep '\[Pending\]' >/dev/null 2>&1
				if [ $? -eq 0 ]; then
					#
					# To Service Out
					#
					chmpxlinetool -conf "${INI_FILE_PATH}" -run "${WATCHER_RECOVER_FILE_PATH}" >/dev/null 2>&1
				fi
				sleep "${SLEEP_MIDDLE}"
			else
				sleep "${SLEEP_LONG}"
				chmpxlinetool -conf "${INI_FILE_PATH}" -run "${WATCHER_STSUPDATE_FILE_PATH}" >/dev/null 2>&1
			fi
		else
			chmpxstatus -conf "${INI_FILE_PATH}" -self -wait -live up -ring serviceout -nosuspend -timeout "${SLEEP_SHORT}" >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				# 
				# When the status is "ServiceOut:NoSuspend", type a new ServiceIn command after short sleep.
				#
				sleep "${SLEEP_MIDDLE}"
				chmpxstatus -conf "${INI_FILE_PATH}" -self -wait -live up -ring serviceout -nosuspend -timeout "${SLEEP_SHORT}" >/dev/null 2>&1
				if [ $? -eq 0 ]; then
					#
					# To Service In
					#
					chmpxlinetool -conf "${INI_FILE_PATH}" -run "${WATCHER_SERVICEIN_FILE_PATH}" >/dev/null 2>&1
				else
					chmpxlinetool -conf "${INI_FILE_PATH}" -run "${WATCHER_STSUPDATE_FILE_PATH}" >/dev/null 2>&1
				fi
			fi
			sleep "${SLEEP_MIDDLE}"
		fi
	done

else
	#
	# Run k2hdkc
	#
	CHMPX_UP=0
	while [ "${CHMPX_UP}" -eq 0 ]; do
		#
		# Check keep status while SLEEP_LONG second
		#
		STATUS_KEEP_TIME="${SLEEP_LONG}"
		while [ "${STATUS_KEEP_TIME}" -gt 0 ]; do
			chmpxstatus -conf "${INI_FILE_PATH}" -self -wait -live up -ring serviceout -suspend -timeout "${SLEEP_SHORT}" >/dev/null 2>&1
			if [ $? -ne 0 ]; then
				chmpxstatus -conf "${INI_FILE_PATH}" -self -wait -live up -ring servicein -suspend -timeout "${SLEEP_SHORT}" >/dev/null 2>&1
				if [ $? -ne 0 ]; then
					break;
				fi
			fi
			sleep "${SLEEP_SHORT}"
			STATUS_KEEP_TIME=$((STATUS_KEEP_TIME - SLEEP_SHORT))
		done

		if [ "${STATUS_KEEP_TIME}" -le 0 ]; then
			CHMPX_UP=1
		else
			sleep "${SLEEP_MIDDLE}"
			RETRYCOUNT=$((RETRYCOUNT - 1))
			if [ "${RETRYCOUNT}" -le 0 ]; then
				break;
			fi
		fi
	done

	if [ "${CHMPX_UP}" -eq 0 ]; then
		exit 1
	fi

	#
	# Run checker process
	#
	/bin/sh "${SCRIPTDIR}/${PRGNAME}" "${WATCHER_OPT}" >/dev/null 2>&1 <&- &

	set -e

	K2HFILE=$(grep K2HFILE "${INI_FILE_PATH}" | sed -e 's/=//g' -e 's/K2HFILE//g' -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g')
	K2HDIR=$(dirname "${K2HFILE}")
	mkdir -p "${K2HDIR}"

	#
	# stdio/stderr is not redirected.
	#
	k2hdkc -conf "${INI_FILE_PATH}" -d err
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
