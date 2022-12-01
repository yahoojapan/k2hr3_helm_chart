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
# Input variables by environment
#----------------------------------------------------------
# USING_SERVICE_NAME		Specify this environment variable and specify its name
#							when using a service such as NodePort
# CERT_PERIOD_DAYS			Specify period days for certificates
# CERT_EXTERNAL_HOSTNAME	Specify external hostname or IP address
#
# CHMPX_INI_TEMPLATE_FILE	Specify chmpx ini template file path
#							(ex. /configmap/k2hr3-k2hdkc.ini.templ)
# CHMPX_INI_DIR				Specify directory path for generated ini file
#							(ex. /etc/antpickax)
#
# CHMPX_MODE				Specify chmpx mode ( SERVER / SLAVE )
# CHMPX_SERVER_PORT			Specify chmpx port number for server node ( 8020 )
# CHMPX_SERVER_CTLPORT		Specify chmpx control port number for server node ( 8021 )
# CHMPX_SLAVE_CTLPORT		Specify chmpx control port number for slave node ( 8022 )
#
# CHMPX_SERVER_COUNT		Specify chmpx server nodes count ( 2... )
# CHMPX_SERVER_NAMEBASE		Specify chmpx server name base ( r3dkc )
#							Based on this value, the server name, FQDN parts, etc.
#							are assembled. (ex. svc-r3dkc, pod-r3dkc-0)
# CHMPX_SLAVE_COUNT			Specify chmpx slave nodes count ( 2... )
# CHMPX_SLAVE_NAMEBASE		Specify chmpx slave name base ( r3api )
#							Based on this value, the slave name, FQDN parts, etc.
#							are assembled. (ex. svc-r3api, pod-r3api-0)
#
# CHMPX_POD_NAMESPACE		Specify kubernetes namespace for k2hdkc cluster ( default )
# CHMPX_DEFAULT_DOMAIN		Specify default local domain name ( svc.cluster.local )
# CHMPX_SELF_HOSTNAME		Specify self node hostname : Unused ( pod-r3dkc-X / pod-r3api-X )
#
# SEC_CA_MOUNTPOINT			Specify mount point for CA certification file
#
#----------------------------------------------------------
# Variables created internally
#----------------------------------------------------------
# CHMPX_SELFPORT				Set self control port by this script
# CHMPX_INI_FILENAME			Set ini file name ( server.ini / slave.ini )
# CHMPX_SSL_SETTING				Set SSL(TLS) mode and certifications
#
set -e

#PRGNAME=$(basename "$0")
SCRIPTDIR=$(dirname "$0")
SCRIPTDIR=$(cd "${SCRIPTDIR}" || exit 1; pwd)

#----------------------------------------------------------
# Common values
#----------------------------------------------------------
CHMPX_SELFPORT=0
CHMPX_INI_FILENAME=""
DATE=$(date -R)

#----------------------------------------------------------
# Check enviroment values
#----------------------------------------------------------
if [ -z "${CHMPX_INI_TEMPLATE_FILE}" ]; then
	exit 1
fi
if [ -z "${CHMPX_INI_DIR}" ]; then
	exit 1
fi
if [ -z "${CHMPX_SERVER_PORT}" ]; then
	exit 1
fi
if [ -z "${CHMPX_SERVER_CTLPORT}" ]; then
	exit 1
fi
if [ -z "${CHMPX_SLAVE_CTLPORT}" ]; then
	exit 1
fi
if [ -z "${CHMPX_SERVER_COUNT}" ]; then
	exit 1
fi
if [ -z "${CHMPX_SERVER_NAMEBASE}" ]; then
	exit 1
fi
if [ -z "${CHMPX_SLAVE_COUNT}" ]; then
	exit 1
fi
if [ -z "${CHMPX_SLAVE_NAMEBASE}" ]; then
	exit 1
fi
if [ -z "${CHMPX_POD_NAMESPACE}" ]; then
	exit 1
fi
if [ -z "${CHMPX_DEFAULT_DOMAIN}" ]; then
	exit 1
fi
if [ -z "${CHMPX_SELF_HOSTNAME}" ]; then
	exit 1
fi

#
# Allow empty value
#
if [ -n "${SEC_CA_MOUNTPOINT}" ] && [ ! -d "${SEC_CA_MOUNTPOINT}" ]; then
	exit 1
fi

#----------------------------------------------------------
# Check ini template file
#----------------------------------------------------------
if [ ! -f "${CHMPX_INI_TEMPLATE_FILE}" ]; then
	exit 1
fi

#----------------------------------------------------------
# Check and Create directory
#----------------------------------------------------------
mkdir -p "${CHMPX_INI_DIR}"

#----------------------------------------------------------
# Set chmpx mode and set common values
#----------------------------------------------------------
if [ -z "${CHMPX_MODE}" ]; then
	exit 1
elif [ "${CHMPX_MODE}" = "SERVER" ] || [ "${CHMPX_MODE}" = "server" ]; then
	CHMPX_MODE="SERVER"
	CHMPX_SELFPORT=${CHMPX_SERVER_CTLPORT}
	CHMPX_INI_FILENAME="server.ini"
elif [ "${CHMPX_MODE}" = "SLAVE" ] || [ "${CHMPX_MODE}" = "slave" ]; then
	CHMPX_MODE="SLAVE"
	CHMPX_SELFPORT=${CHMPX_SLAVE_CTLPORT}
	CHMPX_INI_FILENAME="slave.ini"
else
	exit 1
fi

#----------------------------------------------------------
# For certifications
#----------------------------------------------------------
GLOBAL_PART_SSL="SSL = no"
GLOBAL_PART_SSL_VERIFY_PEER=""
GLOBAL_PART_CAPATH=""
GLOBAL_PART_SERVER_CERT=""
GLOBAL_PART_SERVER_PRIKEY=""
GLOBAL_PART_SLAVE_CERT=""
GLOBAL_PART_SLAVE_PRIKEY=""

if [ -n "${SEC_CA_MOUNTPOINT}" ]; then
	#
	# Create certificate for me
	#
	/bin/sh "${SCRIPTDIR}/k2hr3-setup-certificate.sh" "${CHMPX_INI_DIR}" "${SEC_CA_MOUNTPOINT}" "${CERT_PERIOD_DAYS}" "EXTHOSTNAME=${CERT_EXTERNAL_HOSTNAME}" "${USING_SERVICE_NAME}"

	#
	# Set variables for ini file
	#
	GLOBAL_PART_CAPATH="CAPATH = ${CHMPX_INI_DIR}/ca.crt"
	GLOBAL_PART_SSL="SSL = on"
	GLOBAL_PART_SSL_VERIFY_PEER="SSL_VERIFY_PEER = on"
	GLOBAL_PART_SERVER_CERT="SERVER_CERT = ${CHMPX_INI_DIR}/server.crt"
	GLOBAL_PART_SERVER_PRIKEY="SERVER_PRIKEY = ${CHMPX_INI_DIR}/server.key"
	GLOBAL_PART_SLAVE_CERT="SLAVE_CERT = ${CHMPX_INI_DIR}/client.crt"
	GLOBAL_PART_SLAVE_PRIKEY="SLAVE_PRIKEY = ${CHMPX_INI_DIR}/client.key"
fi

CHMPX_SSL_SETTING="${GLOBAL_PART_SSL}\\n${GLOBAL_PART_SSL_VERIFY_PEER}\\n${GLOBAL_PART_CAPATH}\\n${GLOBAL_PART_SERVER_CERT}\\n${GLOBAL_PART_SERVER_PRIKEY}\\n${GLOBAL_PART_SLAVE_CERT}\\n${GLOBAL_PART_SLAVE_PRIKEY}"

#----------------------------------------------------------
# Create file
#----------------------------------------------------------
{
	#
	# Create Base parts
	#
	sed -e "s#%%CHMPX_DATE%%#${DATE}#g"						\
		-e "s#%%CHMPX_MODE%%#${CHMPX_MODE}#g"				\
		-e "s#%%CHMPX_SELFPORT%%#${CHMPX_SELFPORT}#g"		\
		-e "s#%%CHMPX_SSL_SETTING%%#${CHMPX_SSL_SETTING}#g"	\
		"${CHMPX_INI_TEMPLATE_FILE}"

	#
	# Set server nodes
	#
	echo ""
	echo "#"
	echo "# SERVER NODES SECTION"
	echo "#"

	for counter in $(seq "${CHMPX_SERVER_COUNT}"); do
		NODE_NUMBER=$((counter - 1))
		NODE_NAME="pod-${CHMPX_SERVER_NAMEBASE}-${NODE_NUMBER}.svc-${CHMPX_SERVER_NAMEBASE}.${CHMPX_POD_NAMESPACE}.${CHMPX_DEFAULT_DOMAIN}"

		echo "[SVRNODE]"
		echo "NAME           = ${NODE_NAME}"
		echo "PORT           = ${CHMPX_SERVER_PORT}"
		echo "CTLPORT        = ${CHMPX_SERVER_CTLPORT}"
		echo "CUSTOM_ID_SEED = ${NODE_NAME}"
		echo ""
	done

	#
	# Set slave nodes
	#
	echo "#"
	echo "# SLAVE NODES SECTION"
	echo "#"

	for counter in $(seq "${CHMPX_SLAVE_COUNT}"); do
		NODE_NUMBER=$((counter - 1))
		NODE_NAME="pod-${CHMPX_SLAVE_NAMEBASE}-${NODE_NUMBER}.svc-${CHMPX_SLAVE_NAMEBASE}.${CHMPX_POD_NAMESPACE}.${CHMPX_DEFAULT_DOMAIN}"

		echo "[SLVNODE]"
		echo "NAME           = ${NODE_NAME}"
		echo "CTLPORT        = ${CHMPX_SLAVE_CTLPORT}"
		echo "CUSTOM_ID_SEED = ${NODE_NAME}"
		echo ""
	done

	#
	# Footer
	#
	echo "#"
	echo "# Local variables:"
	echo "# tab-width: 4"
	echo "# c-basic-offset: 4"
	echo "# End:"
	echo "# vim600: noexpandtab sw=4 ts=4 fdm=marker"
	echo "# vim<600: noexpandtab sw=4 ts=4"
	echo "#"

} >> "${CHMPX_INI_DIR}/${CHMPX_INI_FILENAME}"

#----------------------------------------------------------
# Adjustment of startup timing
#----------------------------------------------------------
set +e

WAIT_SEC=5
POD_NUMBER=$(echo "${CHMPX_SELF_HOSTNAME}" | sed 's/-/ /g' | awk '{print $NF}')

# shellcheck disable=SC2003,SC2181
if expr "${POD_NUMBER}" + 1 >/dev/null 2>&1; then
	WAIT_SEC=$((WAIT_SEC * POD_NUMBER))
fi

sleep "${WAIT_SEC}"

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
