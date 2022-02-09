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
# ANTPICKAX_ETC_DIR			Specify directory path for files ( /etc/antpickax )
# CERT_PERIOD_DAYS			Specify period days for certificates
# CERT_EXTERNAL_HOSTNAME	Specify external hostname or IP address
# SEC_CA_MOUNTPOINT			Specify mount point for CA certificate file
#
set -e

#PRGNAME=$(basename "$0")
SCRIPTDIR=$(dirname "$0")
SCRIPTDIR=$(cd "${SCRIPTDIR}" || exit 1; pwd)

#----------------------------------------------------------
# Check enviroment values
#----------------------------------------------------------
if [ "X${ANTPICKAX_ETC_DIR}" = "X" ]; then
	exit 1
fi

#
# Allow empty value
#
if [ "X${SEC_CA_MOUNTPOINT}" != "X" ] && [ ! -d "${SEC_CA_MOUNTPOINT}" ]; then
	exit 1
fi

#----------------------------------------------------------
# Certificates
#----------------------------------------------------------
if [ "X${SEC_CA_MOUNTPOINT}" != "X" ]; then
	#
	# Create certificate for me
	#
	/bin/sh "${SCRIPTDIR}/k2hr3-setup-certificate.sh" "${ANTPICKAX_ETC_DIR}" "${SEC_CA_MOUNTPOINT}" "${CERT_PERIOD_DAYS}" "EXTHOSTNAME=${CERT_EXTERNAL_HOSTNAME}" "${USING_SERVICE_NAME}"
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
