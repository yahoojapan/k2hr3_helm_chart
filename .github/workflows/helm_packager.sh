#!/bin/sh
#
# Utility helper tools for Github Actions by AntPickax
#
# Copyright 2022 Yahoo Japan Corporation.
#
# This common file is supposed to be called from Github Actions,
# which is a Helm Chart packaging process for AntPickax products.
#
# For the full copyright and license information, please view
# the license file that was distributed with this source code.
#
# AUTHOR:   Takeshi Nakatani
# CREATE:   Thu Jan 20 2022
# REVISION:
#

#----------------------------------------------------------
# [NOTE] About this script
#
# This is a script to create a Helm Chart package from the Helm
# Chart repository. It is supposed to be called from the workflow
# of Github Actions.
#
# This script attempts to create a Helm package from the Helm
# Chart repository. The version number and comment in its version
# obtained from CHANGELOG.md are obtained, and the version number
# and comment in Chart.yaml are added. A package will be attempted
# using this edited Chart.yaml.
#
# This is intended to create a package with a unified version and
# comments by editing only CHANGELOG.md in the Github repository.
#
# If this script is pushed to the master(main) branch and the new
# version is listed in CHANGELOG.md, the new version will be
# released.
# In the release, a Git tag(Release Tag) is issued and the Helm
# Chart package is registered in its Asset file. It also updates
# the index.yaml file in gh-pages branch.
#
# There is a "helm-chart-releaser" as a Github Actions similar to
# this script, but we don't use it because the repository
# configuration and release timing are different from what we
# wanted. This script was created instead.
#
#----------------------------------------------------------
# Common variables
#----------------------------------------------------------
PRGNAME=$(basename "$0")
SCRIPTDIR=$(dirname "$0")
SCRIPTDIR=$(cd "${SCRIPTDIR}"/../.. || exit 1; pwd)

SCRIPT_CURRENT_DIR=$(pwd)
WGET_BIN=$(command -v wget | tr -d '\n')

echo "[Info] Test Helm Chart packageing / publishing"
echo ""

#----------------------------------------------------------
# Usage
#
#	helm_packager.sh <chart.yaml file path> <CHANGELOG.md file path>
#
#	$1:		Chart.yaml file path
#	$2:		CHANGELOG.md file path
#
#----------------------------------------------------------
CHART_YAML_FILE="$1"
CHANGELOG_MD_FILE="$2"

if [ -z "${CHART_YAML_FILE}" ]; then
	CHART_YAML_FILE="${SCRIPTDIR}"/Chart.yaml
fi
if [ -z "${CHANGELOG_MD_FILE}" ]; then
	CHANGELOG_MD_FILE="${SCRIPTDIR}"/CHANGELOG.md
fi

if [ ! -f "${CHART_YAML_FILE}" ]; then
	echo "[Error] Not found Chart yaml file(${CHART_YAML_FILE})."
	exit 1
fi
CHART_DIR=$(dirname "${CHART_YAML_FILE}")

if [ ! -f "${CHANGELOG_MD_FILE}" ]; then
	echo "[Error] Not found CHANGELOG.md file(${CHANGELOG_MD_FILE})."
	exit 1
fi

#----------------------------------------------------------
# Repository information
#----------------------------------------------------------
if [ -z "${GITHUB_REPOSITORY}" ]; then
	#
	# Call from not github actions
	#
	if command -v git >/dev/null 2>&1; then
		if [ -d "${SCRIPTDIR}/.git" ]; then
			GITHUB_DOMAIN=$(git remote -v | grep fetch | awk '{print $2}' | sed -e 's/git@//g' -e 's#http[s]*://##g' -e 's/\.git//g' -e 's#[:|/]# #g' | awk '{print $1}' | tr -d '\n')
			ORG_NAME=$(git remote -v | grep fetch | awk '{print $2}' | sed -e 's/git@//g' -e 's#http[s]*://##g' -e 's/\.git//g' -e 's#[:|/]# #g' | awk '{print $2}' | tr -d '\n')
			REPO_NAME=$(git remote -v | grep fetch | awk '{print $2}' | sed -e 's/git@//g' -e 's#http[s]*://##g' -e 's/\.git//g' -e 's#[:|/]# #g' | awk '{print $3}' | tr -d '\n')
			CURRENT_BRANCH=$(git branch | grep '\*' | awk '{print $2}' | tr -d '\n')
		fi
	fi
	if [ -z "${GITHUB_DOMAIN}" ] || [ -z "${ORG_NAME}" ] || [ -z "${REPO_NAME}" ]; then
		echo "[Warning] Could not get repository path(organaization /repository name, etc)."
	fi

	IS_RELEASE_TAG_PROCESS=0
	IN_PUSH_PROCESS=0
	if [ -n "${CURRENT_BRANCH}" ] && [ "${CURRENT_BRANCH}" = "master" ]; then
		IS_MASTER_BRANCH=1
	else
		IS_MASTER_BRANCH=0
	fi
else
	#
	# Call from not github actions
	#
	GITHUB_DOMAIN="github.com"
	ORG_NAME=$(echo "${GITHUB_REPOSITORY}" | awk -F / '{print $1}')
	REPO_NAME=$(echo "${GITHUB_REPOSITORY}" | awk -F / '{print $2}')

	if [ -z "${GITHUB_DOMAIN}" ] || [ -z "${ORG_NAME}" ] || [ -z "${REPO_NAME}" ]; then
		echo "[Warning] Could not get repository path(organaization /repository name, etc)."
	fi

	if [ "${ORG_NAME}" = "yahoojapan" ] || { [ -n "${RUN_TAGGING_ORG}" ] && [ "${ORG_NAME}" = "${RUN_TAGGING_ORG}" ]; }; then
		IS_RELEASE_TAG_PROCESS=1
	else
		IS_RELEASE_TAG_PROCESS=0
	fi

	CURRENT_BRANCH="${GITHUB_REF##*/}"
	if [ -n "${CURRENT_BRANCH}" ] && [ "${CURRENT_BRANCH}" = "master" ]; then
		IS_MASTER_BRANCH=1
	else
		IS_MASTER_BRANCH=0
	fi

	if [ -n "${GITHUB_EVENT_NAME}" ] && [ "${GITHUB_EVENT_NAME}" = "push" ]; then
		IN_PUSH_PROCESS=1
	else
		IN_PUSH_PROCESS=0
	fi
fi

#----------------------------------------------------------
# Create temporary directory / temporary file
#----------------------------------------------------------
TMP_GHPAGES_DIR="/tmp/${PRGNAME}.dir.$$"
rm -rf "${TMP_GHPAGES_DIR}"
mkdir -p "${TMP_GHPAGES_DIR}"

TMP_CHANGELOG_CONTENT_FILE="/tmp/${PRGNAME}.content.$$"
rm -rf "${TMP_CHANGELOG_CONTENT_FILE}"

BACKUP_CHART_YAML_FILE="/tmp/${PRGNAME}_BACKUP_Chart.yaml.$$"
rm -rf "${BACKUP_CHART_YAML_FILE}"

#----------------------------------------------------------
# Utilities
#----------------------------------------------------------
#
# Utility: Check newer version number
#
# $1:	Base version number
# $2:	Traget version number
#
# $?:	return 0 if newer, other is 1
#
check_newer_version_number()
{
	CMP_BASE_VERSION="$1"
	CMP_TG_VERSION="$2"

	if [ -z "${CMP_TG_VERSION}" ]; then
		echo "[Error] target version number is empty."
		return 1
	fi
	if [ -z "${CMP_BASE_VERSION}" ]; then
		#
		# This means first version
		#
		return 0
	fi

	CMP_BASE_VERSION_POS1=$(echo "${CMP_BASE_VERSION}" | awk -F . '{ print $1 }')
	CMP_BASE_VERSION_POS2=$(echo "${CMP_BASE_VERSION}" | awk -F . '{ print $2 }')
	CMP_BASE_VERSION_POS3=$(echo "${CMP_BASE_VERSION}" | awk -F . '{ print $3 }')
	CMP_TG_VERSION_POS1=$(echo "${CMP_TG_VERSION}" | awk -F . '{ print $1 }')
	CMP_TG_VERSION_POS2=$(echo "${CMP_TG_VERSION}" | awk -F . '{ print $2 }')
	CMP_TG_VERSION_POS3=$(echo "${CMP_TG_VERSION}" | awk -F . '{ print $3 }')

	if [ -z "${CMP_BASE_VERSION_POS1}" ] || [ -z "${CMP_TG_VERSION_POS1}" ]; then
		echo "[Warning] base version number(${CMP_BASE_VERSION}) or target(${CMP_TG_VERSION}) is wrong version number."
		return 1
	fi
	if [ "${CMP_BASE_VERSION_POS1}" -lt "${CMP_TG_VERSION_POS1}" ]; then
		return 0
	fi
	if [ -z "${CMP_BASE_VERSION_POS2}" ] || [ -z "${CMP_TG_VERSION_POS2}" ]; then
		echo "[Warning] base version number(${CMP_BASE_VERSION}) or target(${CMP_TG_VERSION}) is wrong version number."
		return 1
	fi
	if [ "${CMP_BASE_VERSION_POS2}" -lt "${CMP_TG_VERSION_POS2}" ]; then
		return 0
	fi
	if [ -z "${CMP_BASE_VERSION_POS3}" ] || [ -z "${CMP_TG_VERSION_POS3}" ]; then
		echo "[Warning] base version number(${CMP_BASE_VERSION}) or target(${CMP_TG_VERSION}) is wrong version number."
		return 1
	fi
	if [ "${CMP_BASE_VERSION_POS3}" -lt "${CMP_TG_VERSION_POS3}" ]; then
		return 0
	fi
	return 1
}

#
# Utility: Get lastest version from CHANGELOG.md
#
# $1:	CHANGELOG.md file path
# $?:	Return 0 if found, other is 1
#
# Set found version to LASTEST_CHANGELOG_VERSION variables
# Set IS_INITIAL_VERSION(1) if there is no version other
# than the detected version
#
get_latest_version_in_changelog()
{
	_CHANGELOG_FILE="$1"
	LASTEST_CHANGELOG_VERSION=""
	IS_INITIAL_VERSION=0

	if [ ! -f "${_CHANGELOG_FILE}" ]; then
		echo "[Error] Not found CHANGELOG.md file(${_CHANGELOG_FILE})."
		return 1
	fi

	_IN_COMMENT=0
	while read -r LINE; do
		#
		# Check version line(Level 2)
		#
		if [ "${_IN_COMMENT}" -eq 0 ]; then
			_FOUND_VERSION_STR=$(echo "${LINE}" | grep "^## \[[0-9]\+\.[0-9]\+\.[0-9]\+\].*$" | sed -e 's/^## \[//g' -e 's/\].*$//g')
			# shellcheck disable=SC2181
			if [ $? -eq 0 ] && [ -n "${_FOUND_VERSION_STR}" ]; then
				if [ -z "${LASTEST_CHANGELOG_VERSION}" ]; then
					LASTEST_CHANGELOG_VERSION="${_FOUND_VERSION_STR}"
					IS_INITIAL_VERSION=1
				else
					if check_newer_version_number "${LASTEST_CHANGELOG_VERSION}" "${_FOUND_VERSION_STR}"; then
						LASTEST_CHANGELOG_VERSION="${_FOUND_VERSION_STR}"
					fi
					IS_INITIAL_VERSION=0
				fi
			elif echo "${LINE}" | grep -q "^.*<\!--.*$"; then
				_IN_COMMENT=1
			else
				:
			fi
		else
			if echo "${LINE}" | grep -q "^.*-->.*$"; then
				_IN_COMMENT=0
			else
				:
			fi
		fi
	done < "${_CHANGELOG_FILE}"

	if [ -z "${LASTEST_CHANGELOG_VERSION}" ]; then
		return 1
	fi
	return 0
}

#
# Utility: Extract contents from CHANGELOG.md
#
# $1:	Version string(ex, 0.0.0)
# $2:	CHANGELOG.md file path
# $3:	Output file path
#
extract_changelog_content()
{
	_TARGET_VERSION="$1"
	_CHANGELOG_FILE="$2"
	_CONTENT_OUTPUT_FILE="$3"

	if [ -z "${_TARGET_VERSION}" ]; then
		echo "[Error] The version number to be extracted from CHANGELOG.md is empty."
		return 1
	fi
	if [ ! -f "${_CHANGELOG_FILE}" ]; then
		echo "[Error] Not found CHANGELOG.md file(${_CHANGELOG_FILE})."
		return 1
	fi
	if ! cat /dev/null > "${_CONTENT_OUTPUT_FILE}"; then
		echo "[Error] Could not write output file(${_CONTENT_OUTPUT_FILE})."
		return 1
	fi

	_IN_TARGET=0
	_IN_COMMENT=0
	_RESULT_CODE=1
	while read -r LINE; do
		if [ "${_IN_TARGET}" -eq 0 ]; then
			#
			# Check target version line(Level 2)
			#
			if [ "${_IN_COMMENT}" -eq 0 ]; then
				if echo "${LINE}" | grep -q "^## \[${_TARGET_VERSION}\].*$"; then
					_IN_TARGET=1
				elif echo "${LINE}" | grep -q "^.*<\!--.*$"; then
					_IN_COMMENT=1
				else
					:
				fi
			else
				if echo "${LINE}" | grep -q "^.*-->.*$"; then
					_IN_COMMENT=0
				else
					:
				fi
			fi
		elif [ "${_IN_TARGET}" -eq 1 ]; then
			#
			# In target version section, Check target version line(Level 3)
			#
			if [ "${_IN_COMMENT}" -eq 0 ]; then
				if echo "${LINE}" | grep -q "^# .*$"; then
					_IN_TARGET=0
				elif echo "${LINE}" | grep -q "^## .*$"; then
					_IN_TARGET=0
				elif echo "${LINE}" | grep -q "^### .*$"; then
					_IN_TARGET=2
				elif echo "${LINE}" | grep -q "^###.*$"; then
					_IN_TARGET=0
				elif echo "${LINE}" | grep -q "^.*<\!--.*$"; then
					_IN_COMMENT=1
				else
					:
				fi
			else
				if echo "${LINE}" | grep -q "^.*-->.*$"; then
					_IN_COMMENT=0
				else
					:
				fi
			fi
		elif [ "${_IN_TARGET}" -eq 2 ]; then
			#
			# In target version section, Check target line(Level 4)
			#
			if [ "${_IN_COMMENT}" -eq 0 ]; then
				if echo "${LINE}" | grep -q "^- .*$"; then
					#
					# Found
					#
					_RESULT_CODE=0
					echo "${LINE}"
				elif echo "${LINE}" | grep -q "^#.*$"; then
					_IN_TARGET=0
				elif echo "${LINE}" | grep -q "^.*<\!--.*$"; then
					_IN_COMMENT=1
				else
					:
				fi
			else
				if echo "${LINE}" | grep -q "^.*-->.*$"; then
					_IN_COMMENT=0
				else
					:
				fi
			fi
		fi
	done < "${_CHANGELOG_FILE}" > "${_CONTENT_OUTPUT_FILE}"

	return "${_RESULT_CODE}"
}

#
# Utility: Replace keyword to multi line file
#
# $1:	keyword
# $2:	replace value file(multi line)
# $3:	file path
# $?:	Return 0 if found, other is 1
#
# Set found version to _LATEST_VERSION variables
#
replace_keyword_file()
{
	_REPLACE_KEYWORD="$1"
	_REPLACE_CONTENT_FILE="$2"
	_TARGET_REPLACED_FILE="$3"
	_REPLACE_TMP_FILE="/tmp/${PRGNAME}.replace.$$"

	if [ -z "${_REPLACE_KEYWORD}" ] || [ ! -f "${_REPLACE_CONTENT_FILE}" ] || [ ! -f "${_TARGET_REPLACED_FILE}" ]; then
		echo "[Error] Input value is wrong: keyword(${_REPLACE_KEYWORD}), replace content file(${_REPLACE_CONTENT_FILE}), target file(${_TARGET_REPLACED_FILE})"
		return 1
	fi

	BACKUP_IFS="${IFS}"
	while IFS="";read -r LINE; do
		_FOUND_KEYWORD_LINE=$(echo "${LINE}" | grep "^[[:space:]]*[-]*[[:space:]]*${_REPLACE_KEYWORD}[[:space:]]*$")
		if [ -n "${_FOUND_KEYWORD_LINE}" ]; then
			_FOUND_PREFIX_STR=$(echo "${_FOUND_KEYWORD_LINE}" | sed -e "s/[-]*[[:space:]]*${_REPLACE_KEYWORD}[[:space:]]*$//g")

			while read -r REPLINE; do
				echo "${_FOUND_PREFIX_STR}${REPLINE}"
			done < "${_REPLACE_CONTENT_FILE}"
		else
			echo "${LINE}"
		fi
	done < "${_TARGET_REPLACED_FILE}" > "${_REPLACE_TMP_FILE}"
	IFS="${BACKUP_IFS}"

	if ! cp "${_REPLACE_TMP_FILE}" "${_TARGET_REPLACED_FILE}"; then
		echo "[Error] Could not override target file(${_TARGET_REPLACED_FILE})."
		return 1
	fi

	rm -f "${_REPLACE_TMP_FILE}"
	return 0
}

#----------------------------------------------------------
# Variaables from Chart.yaml
#----------------------------------------------------------
#
# Chart name
#
if ! CHART_NAME=$(grep '^[n|N]ame:' "${CHART_YAML_FILE}" | sed -e 's/[n|N]ame:[[:space:]]*//g' | tr -d '\n'); then
	echo "[Error] Not found \"name:\" keyword in Chart yaml file(${CHART_YAML_FILE})."
	exit 1
fi

#----------------------------------------------------------
# Information
#----------------------------------------------------------
echo "[Info] Test with following variables:"
echo "       PRGNAME                    = ${PRGNAME}"
echo "       SCRIPTDIR                  = ${SCRIPTDIR}"
echo "       SCRIPT_CURRENT_DIR         = ${SCRIPT_CURRENT_DIR}"
echo "       WGET_BIN                   = ${WGET_BIN}"
echo "       CHART_YAML_FILE            = ${CHART_YAML_FILE}"
echo "       CHANGELOG_MD_FILE          = ${CHANGELOG_MD_FILE}"
echo "       CHART_DIR                  = ${CHART_DIR}"
echo "       GIT DOMAIN                 = ${GITHUB_DOMAIN}"
echo "       ORG_NAME                   = ${ORG_NAME}"
echo "       REPO_NAME                  = ${REPO_NAME}"
echo "       CURRENT_BRANCH             = ${CURRENT_BRANCH}"
echo "       IS_MASTER_BRANCH           = ${IS_MASTER_BRANCH}"
echo "       IN_PUSH_PROCESS            = ${IN_PUSH_PROCESS}"
echo "       CHART_NAME                 = ${CHART_NAME}"
echo "       TMP_GHPAGES_DIR            = ${TMP_GHPAGES_DIR}"
echo "       TMP_CHANGELOG_CONTENT_FILE = ${TMP_CHANGELOG_CONTENT_FILE}"
echo "       BACKUP_CHART_YAML_FILE     = ${BACKUP_CHART_YAML_FILE}"
echo ""

#----------------------------------------------------------
# Version number detection and comparison
#
# Find the latest version number from Gittag and CHANGELOG.md.
# Compare each version number and set a flag(IS_NEW_VERSION)
# to determine if a package needs to be uploaded.
# The version detected from CHANGELOG.md is set to "version"
# and "appVersion" in Chart.md.
#----------------------------------------------------------
#
# Get latest version number from Git tag
#
if ! LATEST_TAG_VERSION=$(git tag | grep '^[v|V]\([e|E][r|R]\([s|S][i|I][o|O][n|N]\)\{0,1\}\)\{0,1\}'| sed 's/^[v|V]\([e|E][r|R]\([s|S][i|I][o|O][n|N]\)\{0,1\}\)\{0,1\}//' | grep -o '[0-9]\+\([\.]\([0-9]\)\+\)\+\(.\)*$' | sed 's/-\(.\)*$//' | sort -t . -n -k 1,1 -k 2,2 -k 3,3 -k 4,4 | uniq | tail -1 | tr -d '\n'); then
	echo "[Warning] Not found git tag for version(ex. \"v1.0.0\")."
	LATEST_TAG_VERSION="0.0.0"
fi

#
# Get lastest version in CHANGELOG.md
#
if ! get_latest_version_in_changelog "${CHANGELOG_MD_FILE}"; then
	echo "[Error] Not found any version in CHANGELOG.md file(${CHANGELOG_MD_FILE})."
	exit 1
fi

#
# Is newer version number
#
IS_NEW_VERSION=0
if check_newer_version_number "${LATEST_TAG_VERSION}" "${LASTEST_CHANGELOG_VERSION}"; then
	IS_NEW_VERSION=1
fi

#
# Set Chart version
#
CHART_VERSION="${LASTEST_CHANGELOG_VERSION}"

echo "[Info] Chart version"
echo "       Latest version from git tag    = ${LATEST_TAG_VERSION}"
echo "       Latest version in CHANGELOG.md = ${LASTEST_CHANGELOG_VERSION}"
echo "       Is first version in this repo  = ${IS_INITIAL_VERSION}"
echo "       Determined chart version       = ${CHART_VERSION}"
echo ""

#----------------------------------------------------------
# Modify Chart.yaml
#
# Fix the "version" and "appVersion" values in Chart.yaml to
# CHART_VERSION.
# Also, set the value extracted from CHANGELOG.md to the value
# of "artifacthub.io/changes".
#----------------------------------------------------------
echo "[Info] Get changes from CHANGELOG.md"
#
# Extract change contents for chart version in CHANGELOG.md
#
if ! extract_changelog_content "${CHART_VERSION}" "${CHANGELOG_MD_FILE}" "${TMP_CHANGELOG_CONTENT_FILE}"; then
	echo "[Error] Something error occurred in extracting contents from CHANGELOG.md."
	exit 1
fi
echo "       => Succeed"

#
# Replace "artifacthub.io/changes" content from CHANGELOG.md
#
echo "[Info] Reflect this change in artifacthub.io/changes(Chart.yaml)"
if ! cp -p "${CHART_YAML_FILE}" "${BACKUP_CHART_YAML_FILE}"; then
	echo "[Error] Could not make backup file for Chart.yaml."
	exit 1
fi
if ! replace_keyword_file "FROM_CHANGELOGMD_CONTENT" "${TMP_CHANGELOG_CONTENT_FILE}" "${CHART_YAML_FILE}"; then
	echo "[Error] Something error occurred in replacing Chart.yaml contents from CHANGELOG.md."
	cp -p "${BACKUP_CHART_YAML_FILE}" "${CHART_YAML_FILE}"
	exit 1
fi
echo "       => Succeed"

#
# Replace "version" and "appVersion" in Chart.yaml
#
echo "[Info] Set version/appVersion in Chart.yaml"
if ! sed -i -e "s/version:.*$/version: ${CHART_VERSION}/g" -e "s/appVersion:.*$/appVersion: \"${CHART_VERSION}\"/g" "${CHART_YAML_FILE}"; then
	echo "[Error] Something error occurred in replacing version in Chart.yaml"
	cp -p "${BACKUP_CHART_YAML_FILE}" "${CHART_YAML_FILE}"
	exit 1
fi
echo "       => Succeed"

echo "[Info] Customized Chart.yaml"
sed -e 's/^/       /g' "${CHART_YAML_FILE}"
echo ""

#----------------------------------------------------------
# Download all asset files
#----------------------------------------------------------
#
# Could not use pushd/popd, these are not supported in POSIX sh.
#
echo "[Info] Get all asset files(pakages)"

if RELEASED_TAG_LIST=$(git tag -l | grep '^[v|V]\([e|E][r|R]\([s|S][i|I][o|O][n|N]\)\{0,1\}\)\{0,1\}'); then
	cd "${TMP_GHPAGES_DIR}" || exit 1

	for VERSION_TAG in ${RELEASED_TAG_LIST}; do
		VERSION_NUMBER=$(echo "${VERSION_TAG}" | sed 's/^[v|V]\([e|E][r|R]\([s|S][i|I][o|O][n|N]\)\{0,1\}\)\{0,1\}//')

		mkdir -p "${TMP_GHPAGES_DIR}/${VERSION_TAG}"
		cd "${TMP_GHPAGES_DIR}/${VERSION_TAG}" || exit 1

		if ! "${WGET_BIN}" --quiet "https://${GITHUB_DOMAIN}/${ORG_NAME}/${REPO_NAME}/releases/download/${VERSION_TAG}/${CHART_NAME}-${VERSION_NUMBER}.tgz"; then
			echo "[Error] Could not get Asset file(https://${GITHUB_DOMAIN}/${ORG_NAME}/${REPO_NAME}/releases/download/${VERSION_TAG}/${CHART_NAME}-${VERSION_NUMBER}.tgz) for ${VERSION_TAG} tag."
			cp -p "${BACKUP_CHART_YAML_FILE}" "${CHART_YAML_FILE}"
			exit 1
		fi
	done
	cd "${SCRIPT_CURRENT_DIR}" || exit 1

	echo "       => Succeed"
else
	echo "       => Succeed : There is no tag list."
fi

#----------------------------------------------------------
# Create helm package(tgz) file
#----------------------------------------------------------
echo "[Info] Create Helm Chart package"

#
# Create package
#
if ! HELM_COMMAND_MSG=$(helm package "${CHART_DIR}" 2>&1); then
	echo "[Error] Could not create helm package file(${CHART_NAME}-${CHART_VERSION}.tgz) : \"${HELM_COMMAND_MSG}\""
	cp -p "${BACKUP_CHART_YAML_FILE}" "${CHART_YAML_FILE}"
	exit 1
fi

#
# Check package file in current directory
#
if [ ! -f "${CHART_NAME}-${CHART_VERSION}.tgz" ]; then
	echo "[Error] Not found created helm package file(${CHART_NAME}-${CHART_VERSION}.tgz)."
	cp -p "${BACKUP_CHART_YAML_FILE}" "${CHART_YAML_FILE}"
	exit 1
fi

#
# Copy package file to temporary directory
#
# [NOTE]
# If there is a file with the same version number, it will
# be override.
# (If the version number has not been updated, overwrite it
# and continue checking with the new file you just created)
#
mkdir -p "${TMP_GHPAGES_DIR}/v${CHART_VERSION}"
if ! cp -p "${CHART_NAME}-${CHART_VERSION}.tgz" "${TMP_GHPAGES_DIR}/v${CHART_VERSION}"; then
	echo "[Error] Failed to copy created helm package file(${CHART_NAME}-${CHART_VERSION}.tgz) to temporary directory(${TMP_GHPAGES_DIR})."
	cp -p "${BACKUP_CHART_YAML_FILE}" "${CHART_YAML_FILE}"
	exit 1
fi

echo "       => Succeed : \"${HELM_COMMAND_MSG}\""

#----------------------------------------------------------
# Create index.yaml file
#----------------------------------------------------------
echo "[Info] Create index.yaml"

#
# Create index.yaml
#
if ! helm repo index "${TMP_GHPAGES_DIR}" --url "https://${GITHUB_DOMAIN}/${ORG_NAME}/${REPO_NAME}/releases/download/"; then
	echo "[Error] Failed to create index.yaml in temporary directory(${TMP_GHPAGES_DIR})."
	cp -p "${BACKUP_CHART_YAML_FILE}" "${CHART_YAML_FILE}"
	exit 1
fi
if [ ! -f "${TMP_GHPAGES_DIR}/index.yaml" ]; then
	echo "[Error] Not found created index.yaml in temporary directory(${TMP_GHPAGES_DIR})."
	cp -p "${BACKUP_CHART_YAML_FILE}" "${CHART_YAML_FILE}"
	exit 1
fi
echo "       => Succeed : ${TMP_GHPAGES_DIR}/index.yaml"

echo "[Info] Created index.yaml"
sed -e 's/^/       /g' "${TMP_GHPAGES_DIR}/index.yaml"
echo ""

#----------------------------------------------------------
# Create git tag name, Asset file
#----------------------------------------------------------
echo "[Info] Create git tag name and Asset file"
echo "       => Start"

#
# tag name
#
echo "[Info] Git tag name"
echo "       => Tag name : v${CHART_VERSION}"

#
# Create release notes file
#
echo "[Info] Create release notes"
_RELEASE_NOTES_TMP_FILE="/tmp/${PRGNAME}.notes.$$"
{
	echo "## Release Version ${CHART_VERSION}"
	echo ""

	if [ "${IS_INITIAL_VERSION}" -eq 1 ]; then
		echo "### First release version"
	else
		echo "### Updates from ${LATEST_TAG_VERSION} to ${CHART_VERSION}"
	fi

	cat "${TMP_CHANGELOG_CONTENT_FILE}"
} > "${_RELEASE_NOTES_TMP_FILE}"
echo "       => Created : ${_RELEASE_NOTES_TMP_FILE}"

echo "[Info] Created release notes"
sed -e 's/^/       /g' "${_RELEASE_NOTES_TMP_FILE}"
echo ""

#
# Restore Chart.yaml from backup
#
if ! cp -p "${BACKUP_CHART_YAML_FILE}" "${CHART_YAML_FILE}"; then
	echo "[Error] Could not restore Chart.yaml from backup."
	exit 1
fi
rm -f "${BACKUP_CHART_YAML_FILE}"

#----------------------------------------------------------
# Create git tag with Asset and Update gh-pages branch
#----------------------------------------------------------
echo "[Info] Create git tag with Asset and Update gh-pages branch"

if [ "${IS_RELEASE_TAG_PROCESS}" -eq 1 ]; then
	if [ "${IS_NEW_VERSION}" -eq 1 ] && [ "${IS_MASTER_BRANCH}" -eq 1 ] && [ "${IN_PUSH_PROCESS}" -eq 1 ]; then
		echo "       => Start"

		#
		# Create git tag with asset
		#
		if [ -z "${GH_TOKEN}" ]; then
			echo "[Error] Not found GH_TOKEN environment."
			exit 1
		fi

		#
		# Check release notes file
		#
		if [ ! -f "${_RELEASE_NOTES_TMP_FILE}" ]; then
			echo "[Error] Not found release note file : ${_RELEASE_NOTES_TMP_FILE}"
			exit 1
		fi

		#
		# Set release tag with asset file
		#
		echo "[Info] Create git tag with Asset"
		if ! GH_COMMAND_MSG=$(gh release create "v${CHART_VERSION}" --notes-file "${_RELEASE_NOTES_TMP_FILE}" --target master --title "Release Version ${CHART_VERSION}" "${TMP_GHPAGES_DIR}/v${CHART_VERSION}/${CHART_NAME}-${CHART_VERSION}.tgz" 2>&1); then
			echo "[Error] Failed to create release tag with asset : \"${GH_COMMAND_MSG}\""
			exit 1
		fi
		echo "       => Succeed : \"${GH_COMMAND_MSG}\""

		#
		# Discard the modification of the current branch
		#
		echo "[Info] Discard the modification of the current branch(master) before switch branch to gh-pages"
		if ! GIT_COMMAND_MSG=$(git checkout . 2>&1); then
			echo "[Error] Failed to reset current branch(master) : \"${GIT_COMMAND_MSG}\""
		fi
		if [ -n "${GIT_COMMAND_MSG}" ]; then
			echo "       => Succeed : \"${GIT_COMMAND_MSG}\""
		else
			echo "       => Succeed"
		fi

		#
		# Update gh-pages
		#
		echo "[Info] Update gh-pages"
		if ! git checkout gh-pages; then
			echo "[Error] Could not change branch to gh-pages."
			exit 1
		fi
		if ! cp "${TMP_GHPAGES_DIR}/index.yaml" .; then
			echo "[Error] Could not update index.yaml to current directory."
			exit 1
		fi
		if ! git add index.yaml; then
			echo "[Error] Failed to run \"git add index.yaml\"."
			exit 1
		fi
		if ! git commit -m "Updated index.yaml for release version ${CHART_VERSION}"; then
			echo "[Error] Failed to run \"git commit for gh-pages\"."
			exit 1
		fi
		if ! git push origin gh-pages; then
			echo "[Error] Failed to run \"git push origin gh-pages\"."
			exit 1
		fi
		echo "       => Succeed"
	else
		echo "       => Skipped(this process is not for release or local building)"
	fi
else
	echo "       => Skipped(this repository does not set a release tag or local building)"
fi

#----------------------------------------------------------
# Finish
#----------------------------------------------------------
echo "[Info] All processes are complete"

exit 0

#
# Local variables:
# tab-width: 4
# c-basic-offset: 4
# End:
# vim600: noexpandtab sw=4 ts=4 fdm=marker
# vim<600: noexpandtab sw=4 ts=4
#
