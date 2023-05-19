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
# Usage: script <output dir> <CA certs dir> <period days> <service name> <service name>...
# 
# Specify the name of the service that has the ClusterIP,
# such as NodePort.
# Get the IP address from the environment variable using
# the specified service name.
# The obtained IP address will be used as the IP address
# of the SAN of the certificate.
#
#----------------------------------------------------------
PRGNAME=$(basename "$0")
SCRIPTDIR=$(dirname "$0")
SCRIPTDIR=$(cd "${SCRIPTDIR}" || exit 1; pwd)

#----------------------------------------------------------
# Parse parameter
#----------------------------------------------------------
#
# 1'st parameter is output directory path(ex. /etc/antpickax).
#
if [ $# -lt 1 ]; then
	echo "[ERROR] First paranmeter for output directory path is needed."
	exit 1
fi
if [ ! -d "$1" ]; then
	echo "[ERROR] First paranmeter for output directory path is not directory."
	exit 1
fi
OUTPUT_DIR="$1"
shift

#
# 2'nd parameter is directory path(ex. /secret-ca) for CA certificate.
#
if [ $# -lt 1 ]; then
	echo "[ERROR] Second paranmeter for CA certificate directory path is needed."
	exit 1
fi
if [ ! -d "$1" ]; then
	echo "[ERROR] Second paranmeter for CA certificate directory path is not directory."
	exit 1
fi
CA_CERT_DIR="$1"
shift

#
# 3'rd parameter is period days for certificate(ex. 3650).
#
if [ $# -lt 1 ]; then
	echo "[ERROR] Third paranmeter for period days is not specified."
	exit 1
fi
if echo "$1" | grep -q '[^0-9]'; then
	echo "[ERROR] Third paranmeter for period days is not number."
	exit 1
fi
CERT_PERIOD_DAYS="$1"
shift

#
# 4'th parameter is external hostname.
#
if [ $# -lt 1 ]; then
	echo "[ERROR] 4th paranmeter is not existed."
	exit 1
fi
SAN_EXTHOSTNAME=""
TMP_EXTHOSTNAME=$(echo "$1" | sed -e 's/EXTHOSTNAME=//g')
if [ -n "${TMP_EXTHOSTNAME}" ]; then
	if echo "${TMP_EXTHOSTNAME}" | grep -q -E -o '^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$' 2>/dev/null; then
		SAN_EXTHOSTNAME="IP:${TMP_EXTHOSTNAME}"
	else
		if echo "${TMP_EXTHOSTNAME}" | grep -q -E -o '^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$'; then
			SAN_EXTHOSTNAME="IP:${TMP_EXTHOSTNAME}"
		else
			SAN_EXTHOSTNAME="DNS:${TMP_EXTHOSTNAME}"
		fi
	fi
fi

#
# After parameters are Service name for IP address
#
SERVICE_IP_SANS=""
while [ $# -ne 0 ]; do
	if [ -n "$1" ]; then
		#
		# Parameter is service name(ex. "np-r3app").
		# Then convert it to environment name(ex. NP_R3APP_SERVICE_HOST) for IP address
		#
		TMP_SERVICE_NAME=$(echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
		TMP_SERVICE_NAME="${TMP_SERVICE_NAME}_SERVICE_HOST="
		TMP_SERVICE_IP=$(env | grep "${TMP_SERVICE_NAME}" | sed -e "s/${TMP_SERVICE_NAME}//g")

		if [ -n "${TMP_SERVICE_IP}" ]; then
			if [ -z "${SERVICE_IP_SANS}" ]; then
				SERVICE_IP_SANS="IP:${TMP_SERVICE_IP}"
			else
				SERVICE_IP_SANS="${SERVICE_IP_SANS}, IP:${TMP_SERVICE_IP}"
			fi
		fi
	fi
	shift
done

#----------------------------------------------------------
# Variables
#----------------------------------------------------------
#
# Hostnames / IP addresses
#
# LOCAL_DOMAIN			ex. default.svc.cluster.local
# LOCAL_HOST_DOMAIN		ex. svc.default.svc.cluster.local
# FULL_HOST_NAME		ex. pod.svc.default.svc.cluster.local
# SHORT_HOST_NAME		ex. pod
# NODOMAIN_HOST_NAME	ex. pod.svc
#
LOCAL_DOMAIN="${CHMPX_POD_NAMESPACE}.${CHMPX_DEFAULT_DOMAIN}"
LOCAL_HOST_DOMAIN=$(hostname -d)
LOCAL_HOST_IP=$(hostname -i)
FULL_HOST_NAME=$(hostname -f)
SHORT_HOST_NAME=$(hostname -s)
NODOMAIN_HOST_NAME=$(echo "${FULL_HOST_NAME}" | sed -e "s/\.${LOCAL_DOMAIN}//g")

#
# Certificate directories / files
#
CERT_WORK_DIR="${OUTPUT_DIR}/certwork"

if [ ! -d "${CERT_WORK_DIR}" ]; then
	if ! mkdir -p "${CERT_WORK_DIR}"; then
		echo "[ERROR] Could not create directory ${CERT_WORK_DIR}"
		exit 1
	fi
	if ! mkdir -p "${CERT_WORK_DIR}/private"; then
		echo "[ERROR] Could not create directory ${CERT_WORK_DIR}/private"
		exit 1
	fi
	if ! mkdir -p "${CERT_WORK_DIR}/newcerts"; then
		echo "[ERROR] Could not create directory ${CERT_WORK_DIR}/newcerts"
		exit 1
	fi
	if ! mkdir -p "${CERT_WORK_DIR}/oldcerts"; then
		echo "[ERROR] Could not create directory ${CERT_WORK_DIR}/oldcerts"
		exit 1
	fi
	if ! date +%s > "${CERT_WORK_DIR}/serial"; then
		echo "[ERROR] Could not create file ${CERT_WORK_DIR}/serial"
		exit 1
	fi
	if ! touch "${CERT_WORK_DIR}/index.txt"; then
		echo "[ERROR] Could not create file ${CERT_WORK_DIR}/index.txt"
		exit 1
	fi
fi

#
# Configration files for openssl
#
ORG_OPENSSL_CNF="/etc/ssl/openssl.cnf"
CUSTOM_OPENSSL_CNF="${CERT_WORK_DIR}/openssl.cnf"

SUBJ_CSR_C="JP"
SUBJ_CSR_S="Tokyo"
SUBJ_CSR_O="AntPickax"

#
# CA certificate / private key files
#
# ORG_CA_CERT_FILE	CA certification(ex. default.svc.cluster.local_CA.crt)
# ORG_CA_KEY_FILE	CA private key(ex. default.svc.cluster.local_CA.key)
#
ORG_CA_CERT_FILE=$(find "${CA_CERT_DIR}/" -name '*_CA.crt' | head -1)
ORG_CA_KEY_FILE=$(find "${CA_CERT_DIR}/" -name '*_CA.key' | head -1)
if [ -z "${ORG_CA_CERT_FILE}" ] || [ -z "${ORG_CA_KEY_FILE}" ]; then
	echo "[ERROR] CA certificate file or private key file are not existed."
	exit 1
fi
cp -p "${ORG_CA_CERT_FILE}" "${CERT_WORK_DIR}/cacert.pem"
cp -p "${ORG_CA_KEY_FILE}"  "${CERT_WORK_DIR}/private/cakey.pem"
chmod 0400 "${CERT_WORK_DIR}/private/cakey.pem"

#
# Certificate and private files
#
RAW_CERT_FILE="${CERT_WORK_DIR}/${FULL_HOST_NAME}.crt"
RAW_CSR_FILE="${CERT_WORK_DIR}/${FULL_HOST_NAME}.csr"
RAW_KEY_FILE="${CERT_WORK_DIR}/${FULL_HOST_NAME}.key"

CA_CERT_FILE="${OUTPUT_DIR}/ca.crt"
SERVER_CERT_FILE="${OUTPUT_DIR}/server.crt"
SERVER_KEY_FILE="${OUTPUT_DIR}/server.key"
CLIENT_CERT_FILE="${OUTPUT_DIR}/client.crt"
CLIENT_KEY_FILE="${OUTPUT_DIR}/client.key"

#
# Others
#
LOG_FILE="${CERT_WORK_DIR}/${PRGNAME}.log"

#----------------------------------------------------------
# Check openssl command
#----------------------------------------------------------
if ! command -v openssl >/dev/null 2>&1; then
	if [ ! -f /etc/os-release ]; then
		echo "[ERROR] Not found /etc/os-release file."
		exit 1
	fi
	OS_NAME=$(grep '^ID[[:space:]]*=[[:space:]]*' /etc/os-release | sed -e 's|^ID[[:space:]]*=[[:space:]]*||g' -e 's|^[[:space:]]*||g' -e 's|[[:space:]]*$||g' -e 's|"||g')

	if echo "${OS_NAME}" | grep -q -i "alpine"; then
		if ! apk update -q --no-progress >/dev/null 2>&1 || ! apk add -q --no-progress --no-cache openssl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install openssl."
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

		if ! apt-get update -y -q -q >/dev/null 2>&1 || ! apt-get install -y openssl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install openssl."
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i "centos"; then
		if ! yum update -y -q >/dev/null 2>&1 || ! yum install -y openssl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install openssl."
			exit 1
		fi
	elif echo "${OS_NAME}" | grep -q -i -e "rocky" -e "fedora"; then
		if ! dnf update -y -q >/dev/null 2>&1 || ! dnf install -y openssl >/dev/null 2>&1; then
			echo "[ERROR] Failed to install openssl."
			exit 1
		fi
	else
		echo "[ERROR] Unknown OS type(${OS_NAME})."
		exit 1
	fi
fi
OPENSSL_COMMAND=$(command -v openssl | tr -d '\n')

#----------------------------------------------------------
# Create openssl.cnf 
#----------------------------------------------------------
if [ ! -f "${ORG_OPENSSL_CNF}" ]; then
	echo "[ERROR] Could not find file ${ORG_OPENSSL_CNF}"
	exit 1
fi

#
# Create openssl.cnf from /etc/pki/tls/openssl.cnf
# Modify values
#	unique_subject		= no						in [ CA_default ] section
#	email_in_dn			= no						in [ CA_default ] section
#	rand_serial			= no						in [ CA_default ] section
#	unique_subject		= no						in [ CA_default ] section
#	dir      			= <K2HDKC DBaaS K8S domain>	in [ CA_default ] section
#	keyUsage 			= cRLSign, keyCertSign		in [ v3_ca ] section
#	countryName			= optional					in [ policy_match ] section
#	stateOrProvinceName = optional					in [ policy_match ] section
#	organizationName	= optional					in [ policy_match ] section
#
if ! sed -e 's/\[[[:space:]]*CA_default[[:space:]]*\]/\[ CA_default ]\nunique_subject = no\nemail_in_dn = no\nrand_serial = no/g' \
		-e 's/\[[[:space:]]*v3_ca[[:space:]]*\]/\[ v3_ca ]\nkeyUsage = cRLSign, keyCertSign/g'						\
		-e "s#^dir[[:space:]]*=[[:space:]]*.*CA.*#dir = ${CERT_WORK_DIR}#g"											\
		-e 's/^[[:space:]]*countryName[[:space:]]*=[[:space:]]*match.*$/countryName = optional/g'					\
		-e 's/^[[:space:]]*stateOrProvinceName[[:space:]]*=[[:space:]]*match.*$/stateOrProvinceName = optional/g'	\
		-e 's/^[[:space:]]*organizationName[[:space:]]*=[[:space:]]*match.*$/organizationName = optional/g'			\
		"${ORG_OPENSSL_CNF}"																						\
		> "${CUSTOM_OPENSSL_CNF}"; then

	echo "[ERROR] Could not create file ${CUSTOM_OPENSSL_CNF}"
	exit 1
fi


#
# Add section to  openssl.cnf
#	[ v3_svr_clt ]									add section
#
SAN_SETTINGS=""
if [ -n "${FULL_HOST_NAME}" ]; then
	SAN_SETTINGS="DNS:${FULL_HOST_NAME}"
fi
if [ -n "${LOCAL_HOST_DOMAIN}" ]; then
	if [ -z "${SAN_SETTINGS}" ]; then
		SAN_SETTINGS="DNS:${LOCAL_HOST_DOMAIN}"
	else
		SAN_SETTINGS="${SAN_SETTINGS}, DNS:${LOCAL_HOST_DOMAIN}"
	fi
fi
if [ -n "${SHORT_HOST_NAME}" ]; then
	if [ -z "${SAN_SETTINGS}" ]; then
		SAN_SETTINGS="DNS:${SHORT_HOST_NAME}"
	else
		SAN_SETTINGS="${SAN_SETTINGS}, DNS:${SHORT_HOST_NAME}"
	fi
fi
if [ -n "${NODOMAIN_HOST_NAME}" ]; then
	if [ -z "${SAN_SETTINGS}" ]; then
		SAN_SETTINGS="DNS:${NODOMAIN_HOST_NAME}"
	else
		SAN_SETTINGS="${SAN_SETTINGS}, DNS:${NODOMAIN_HOST_NAME}"
	fi
fi
if [ -n "${LOCAL_HOST_IP}" ]; then
	if [ -z "${SAN_SETTINGS}" ]; then
		SAN_SETTINGS="IP:${LOCAL_HOST_IP}"
	else
		SAN_SETTINGS="${SAN_SETTINGS}, IP:${LOCAL_HOST_IP}"
	fi
fi
if [ -n "${SERVICE_IP_SANS}" ]; then
	if [ -z "${SAN_SETTINGS}" ]; then
		SAN_SETTINGS="${SERVICE_IP_SANS}"
	else
		SAN_SETTINGS="${SAN_SETTINGS}, ${SERVICE_IP_SANS}"
	fi
fi
if [ -n "${SAN_EXTHOSTNAME}" ]; then
	if [ -z "${SAN_SETTINGS}" ]; then
		SAN_SETTINGS="${SAN_EXTHOSTNAME}"
	else
		SAN_SETTINGS="${SAN_SETTINGS}, ${SAN_EXTHOSTNAME}"
	fi
fi
{
	echo ""
	echo "[ v3_svr_clt ]"
	echo "basicConstraints=CA:FALSE"
	echo "keyUsage = digitalSignature, keyEncipherment"
	echo "extendedKeyUsage = serverAuth, clientAuth"
	echo "subjectKeyIdentifier=hash"
	echo "authorityKeyIdentifier=keyid,issuer"
	if [ -n "${SAN_SETTINGS}" ]; then
		echo "subjectAltName = ${SAN_SETTINGS}"
	fi
} >> "${CUSTOM_OPENSSL_CNF}"

# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
	echo "[ERROR] Could not modify file ${CUSTOM_OPENSSL_CNF}"
	exit 1
fi

#----------------------------------------------------------
# Create certificates
#----------------------------------------------------------
#
# Create private key(2048 bit) without passphrase
#
if ! "${OPENSSL_COMMAND}" genrsa	\
		-out "${RAW_KEY_FILE}"		\
		2048						\
		>> "${LOG_FILE}" 2>&1; then

	echo "[ERROR] Failed to create ${RAW_KEY_FILE} private key."
	exit 1
fi

if ! chmod 0400 "${RAW_KEY_FILE}"; then
	echo "[ERROR] Failed to set permission(0400) to ${RAW_KEY_FILE} private key."
	exit 1
fi

#
# Create CSR file
#
if ! "${OPENSSL_COMMAND}" req	\
		-new					\
		-key  "${RAW_KEY_FILE}"	\
		-out  "${RAW_CSR_FILE}"	\
		-subj "/C=${SUBJ_CSR_C}/ST=${SUBJ_CSR_S}/O=${SUBJ_CSR_O}/CN=${NODOMAIN_HOST_NAME}"	\
		>> "${LOG_FILE}" 2>&1; then

	echo "[ERROR] Failed to create ${RAW_CSR_FILE} CSR file."
	exit 1
fi

#
# Create certificate file
#
if ! "${OPENSSL_COMMAND}" ca				\
		-batch								\
		-extensions	v3_svr_clt				\
		-out		"${RAW_CERT_FILE}"		\
		-days		"${CERT_PERIOD_DAYS}"	\
		-passin		"pass:"					\
		-config		"${CUSTOM_OPENSSL_CNF}" \
		-infiles	"${RAW_CSR_FILE}"		\
		>> "${LOG_FILE}" 2>&1; then

	echo "[ERROR] Failed to create ${RAW_CERT_FILE} certificate file."
	exit 1
fi

#----------------------------------------------------------
# Set files to /etc/antpickax
#----------------------------------------------------------
if	! cp -p "${ORG_CA_CERT_FILE}"	"${CA_CERT_FILE}"		||
	! cp -p "${RAW_CERT_FILE}"		"${SERVER_CERT_FILE}"	||
	! cp -p "${RAW_KEY_FILE}"		"${SERVER_KEY_FILE}"	||
	! cp -p "${RAW_CERT_FILE}"		"${CLIENT_CERT_FILE}"	||
	! cp -p "${RAW_KEY_FILE}"		"${CLIENT_KEY_FILE}"	||
	! chmod 0444 "${CA_CERT_FILE}"							||
	! chmod 0444 "${SERVER_CERT_FILE}"						||
	! chmod 0400 "${SERVER_KEY_FILE}"						||
	! chmod 0444 "${CLIENT_CERT_FILE}"						||
	! chmod 0400 "${CLIENT_KEY_FILE}"; then

	echo "[ERROR] Failed to copy certificate files."
	exit 1
fi

#
# Cleanup files
#
if ! rm -rf "${CERT_WORK_DIR}"; then
	echo "[ERROR] Could not remove directory ${CERT_WORK_DIR}"
	exit 1
fi

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
