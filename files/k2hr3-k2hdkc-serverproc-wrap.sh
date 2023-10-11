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
FILE_RETRYCOUNT=60
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
		sleep "${SLEEP_SHORT}"
	fi
done

#----------------------------------------------------------
# Convert configuration file for NSSDB
#----------------------------------------------------------
#
# Get OS name
#
if [ ! -f /etc/os-release ]; then
	echo "[ERROR] Not found /etc/os-release file."
	exit 1
fi
OS_NAME=$(grep '^ID[[:space:]]*=[[:space:]]*' /etc/os-release | sed -e 's|^ID[[:space:]]*=[[:space:]]*||g' -e 's|^[[:space:]]*||g' -e 's|[[:space:]]*$||g' -e 's|"||g')

# [NOTE]
# For Fedora and Rocky Linux, modify the INI file to use NSSDB.
#
if echo "${OS_NAME}" | grep -q -i -e "rocky" -e "fedora"; then
	if ! command -v chmpxnssutil.sh >/dev/null 2>&1; then
		echo "[ERROR] Not found chmpxnssutil.sh file."
		exit 1
	fi

	#
	# Cert paths
	#
	INI_CAFILE=$(grep '^[[:space:]]*CAPATH' "${INI_FILE_PATH}" | sed -e 's#^[[:space:]]*CAPATH[[:space:]]*=[[:space:]]*##g')
	BASE_CAPATH="${ANTPICKAX_ETC_DIR}"
	PARAM_CAFILE=""
	if [ -f "${INI_CAFILE}" ]; then
		BASE_CAPATH=$(dirname "${INI_CAFILE}")
		PARAM_CAFILE="--ca-cert ${INI_CAFILE}"
	elif [ -d "${INI_CAFILE}" ]; then
		if [ -f "${INI_CAFILE}/ca.crt" ]; then
			BASE_CAPATH="${INI_CAFILE}"
			PARAM_CAFILE="--ca-cert ${BASE_CAPATH}/ca.crt"
		fi
	fi
	BASE_SERVER_CERT=$(grep '^[[:space:]]*SERVER_CERT' "${INI_FILE_PATH}" | sed -e 's#^[[:space:]]*SERVER_CERT[[:space:]]*=[[:space:]]*##g')
	BASE_SERVER_PRIKEY=$(grep '^[[:space:]]*SERVER_PRIKEY' "${INI_FILE_PATH}" | sed -e 's#^[[:space:]]*SERVER_PRIKEY[[:space:]]*=[[:space:]]*##g')
	BASE_SLAVE_CERT=$(grep '^[[:space:]]*SLAVE_CERT' "${INI_FILE_PATH}" | sed -e 's#^[[:space:]]*SLAVE_CERT[[:space:]]*=[[:space:]]*##g')
	BASE_SLAVE_PRIKEY=$(grep '^[[:space:]]*SLAVE_PRIKEY' "${INI_FILE_PATH}" | sed -e 's#^[[:space:]]*SLAVE_PRIKEY[[:space:]]*=[[:space:]]*##g')

	#
	# Import certs to NSSDB
	#
	rm -f "${ANTPICKAX_ETC_DIR}"/*.p12

	if ! chmpxnssutil.sh init >/dev/null 2>&1; then
		echo "[ERROR] Could not initialize NSSDB."
		exit 1
	fi
	if ! /bin/sh -c "chmpxnssutil.sh all --cert ${BASE_SERVER_CERT} --key ${BASE_SERVER_PRIKEY} ${PARAM_CAFILE}" >/dev/null 2>&1; then
		echo "[ERROR] Could not import server cert to NSSDB."
		exit 1
	fi
	if ! /bin/sh -c "chmpxnssutil.sh all --cert ${BASE_SLAVE_CERT} --key ${BASE_SLAVE_PRIKEY} ${PARAM_CAFILE}" >/dev/null 2>&1; then
		echo "[ERROR] Could not import client cert to NSSDB."
		exit 1
	fi

	#
	# Get cert's Nicknames
	#
	SERVER_P12_SUFFIX=$(basename "${BASE_SERVER_CERT}" | sed -e 's#[\.].*$##g')
	SERVER_P12_SUFFIX="_${SERVER_P12_SUFFIX}.p12"
	SERVER_CERT_NN=$(find "${ANTPICKAX_ETC_DIR}" -name \*"${SERVER_P12_SUFFIX}" | sed -e "s#${ANTPICKAX_ETC_DIR}/##g" -e "s#${SERVER_P12_SUFFIX}##g")
	SERVER_PRIKEY_NN="${SERVER_CERT_NN}"

	SLAVE_P12_SUFFIX=$(basename "${BASE_SLAVE_CERT}" | sed -e 's#[\.].*$##g')
	SLAVE_P12_SUFFIX="_${SLAVE_P12_SUFFIX}.p12"
	SLAVE_CERT_NN=$(find "${ANTPICKAX_ETC_DIR}" -name \*"${SLAVE_P12_SUFFIX}" | sed -e "s#${ANTPICKAX_ETC_DIR}/##g" -e "s#${SLAVE_P12_SUFFIX}##g")
	SLAVE_PRIKEY_NN="${SLAVE_CERT_NN}"

	#
	# Convert
	#
	NSS_INI_FILE_PATH="${ANTPICKAX_ETC_DIR}/nss_${K2HDDKC_MODE}.ini"
	NSS_INI_FILE_TMPFILE="/tmp/nss_${K2HDDKC_MODE}.ini"

	if ! sed -e "s#^[[:space:]]*CAPATH[[:space:]]*=.*#CAPATH = ${BASE_CAPATH}#g"					\
			 -e "s#^[[:space:]]*SERVER_CERT[[:space:]]*=.*#SERVER_CERT = ${SERVER_CERT_NN}#g"		\
			 -e	"s#^[[:space:]]*SERVER_PRIKEY[[:space:]]*=.*#SERVER_PRIKEY = ${SERVER_PRIKEY_NN}#g"	\
			 -e	"s#^[[:space:]]*SLAVE_CERT[[:space:]]*=.*#SLAVE_CERT = ${SLAVE_CERT_NN}#g"			\
			 -e	"s#^[[:space:]]*SLAVE_PRIKEY[[:space:]]*=.*#SLAVE_PRIKEY = ${SLAVE_PRIKEY_NN}#g"	\
			 "${INI_FILE_PATH}" > "${NSS_INI_FILE_TMPFILE}" 2>/dev/null; then

		echo "[ERROR] Failed to convert ini file(${INI_FILE_PATH})."
		exit 1
	fi

	#
	# Check & copy ini file
	#
	# [NOTE]
	# Copy only if the file has changes. This is to avoid conflicts with other PODs.
	#
	if [ -f "${NSS_INI_FILE_PATH}" ]; then
		if ! cmp "${NSS_INI_FILE_PATH}" "${NSS_INI_FILE_TMPFILE}" >/dev/null 2>&1; then
			cp "${NSS_INI_FILE_TMPFILE}" "${NSS_INI_FILE_PATH}"
		fi
	else
		cp "${NSS_INI_FILE_TMPFILE}" "${NSS_INI_FILE_PATH}"
	fi
	rm -f "${NSS_INI_FILE_TMPFILE}"

	#
	# Swap
	#
	INI_FILE_PATH="${NSS_INI_FILE_PATH}"
fi

#----------------------------------------------------------
# Main processing
#----------------------------------------------------------
if [ -n "$1" ] && [ "$1" = "${WATCHER_OPT}" ]; then
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
		if chmpxstatus -conf "${INI_FILE_PATH}" -self -wait -live up -ring servicein -nosuspend -timeout "${SLEEP_SHORT}" >/dev/null 2>&1; then
			if chmpxstatus -conf "${INI_FILE_PATH}" -self | grep 'status[[:space:]]*=' | grep '\[ADD\]' | grep '\[Pending\]' >/dev/null 2>&1; then
				# 
				# When the status is "ADD:Pending", type a new ServiceIn command after short sleep.
				#
				sleep ${SLEEP_MIDDLE}
				if chmpxstatus -conf "${INI_FILE_PATH}" -self | grep 'status[[:space:]]*=' | grep '\[ADD\]' | grep '\[Pending\]' >/dev/null 2>&1; then
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
			if chmpxstatus -conf "${INI_FILE_PATH}" -self -wait -live up -ring serviceout -nosuspend -timeout "${SLEEP_SHORT}" >/dev/null 2>&1; then
				# 
				# When the status is "ServiceOut:NoSuspend", type a new ServiceIn command after short sleep.
				#
				sleep "${SLEEP_MIDDLE}"
				if chmpxstatus -conf "${INI_FILE_PATH}" -self -wait -live up -ring serviceout -nosuspend -timeout "${SLEEP_SHORT}" >/dev/null 2>&1; then
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
			if ! chmpxstatus -conf "${INI_FILE_PATH}" -self -wait -live up -ring serviceout -suspend -timeout "${SLEEP_SHORT}" >/dev/null 2>&1; then
				if ! chmpxstatus -conf "${INI_FILE_PATH}" -self -wait -live up -ring servicein -suspend -timeout "${SLEEP_SHORT}" >/dev/null 2>&1; then
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
