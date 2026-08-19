#!/bin/sh
set -e

# SPDX-FileCopyrightText: 2025 STRATO GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

################################################################################
# HiDrive Next Apps Configuration Script
################################################################################
#
# DESCRIPTION:
#   This script manages Nextcloud app configurations by:
#   1. Removing specified apps from the shipped.json file (disabling them)
#   2. Adding specified apps to the alwaysEnabled array (forcing them enabled)
#
#   It modifies the 'defaultEnabled' and 'alwaysEnabled' arrays in core/shipped.json
#   to control which apps are shipped with the installation and which cannot be
#   disabled by administrators.
#
# LOCATION:
#   This script is located in /IONOS as a submodule within the Nextcloud
#   server repository.
#
# EXECUTION CONTEXT:
#   This script modifies the shipped.json file, so it should not be executed
#   for every Nextcloud pod in K8s. Since we do not use any PVCs, it would
#   need to be applied for each pod individually. Therefore this script should
#   be executed during the image build.
#
# USAGE:
#   ./apps-disable.sh
#
#   The script reads app names from:
#   - disabled-apps.list: Apps to remove from shipped.json (one per line)
#   - always-enabled-apps.list: Apps to add to alwaysEnabled array (one per line)
#
# PREREQUISITES:
#   - jq (JSON processor) must be installed
#   - disabled-apps.list must exist in the same directory
#   - always-enabled-apps.list is optional but will be processed if present
#   - ../core/shipped.json must exist and be valid JSON
#
################################################################################

# Configuration: Base directory and file paths
BDIR="$(dirname "${0}")"
SHIPPED_JSON="${BDIR}/../core/shipped.json"
DISABLED_APPS_FILE="${BDIR}/disabled-apps.list"
ALWAYS_ENABLED_APPS_FILE="${BDIR}/always-enabled-apps.list"

# Log fatal error message and exit with failure code
# Usage: log_fatal <message>
log_fatal() {
	echo "\033[1;31m[x] Fatal Error: ${*}\033[0m" >&2
	exit 1
}

# Read app list from file, ignoring comments and empty lines
# Usage: read_app_list <file_path>
read_app_list() {
	_list_file="${1}"
	if [ ! -f "${_list_file}" ]; then
		echo ""
		return
	fi
	grep -v '^[[:space:]]*#' "${_list_file}" | grep -v '^[[:space:]]*$' | tr '\n' ' '
}

# Remove an app from both defaultEnabled and alwaysEnabled arrays in shipped.json
# Usage: unship_app <app_name>
unship_app() {
	app="${1}"
	temp_file="${SHIPPED_JSON}.tmp"

	if ! jq --arg app "${app}" \
		'del(.defaultEnabled[] | select(. == $app)) | del(.alwaysEnabled[] | select(. == $app))' \
		"${SHIPPED_JSON}" > "${temp_file}"; then
		log_fatal "Failed to process ${app} with jq"
	fi

	mv "${temp_file}" "${SHIPPED_JSON}"
	echo "Unshipped app '${app}'"
}

# Add an app to the alwaysEnabled array in shipped.json if not already present
# Usage: ship_app <app_name>
ship_app() {
	app="${1}"
	temp_file="${SHIPPED_JSON}.tmp"

	if ! jq --arg app "${app}" \
		'if (.alwaysEnabled | index($app)) then . else .alwaysEnabled += [$app] end' \
		"${SHIPPED_JSON}" > "${temp_file}"; then
		log_fatal "Failed to process ${app} with jq"
	fi

	mv "${temp_file}" "${SHIPPED_JSON}"
	echo "Shipped app '${app}' as always enabled"
}

main() {
	if ! which jq >/dev/null 2>&1; then
		log_fatal "jq is required"
	fi

	if [ ! -f "${SHIPPED_JSON}" ]; then
		log_fatal "Shipped JSON file not found: ${SHIPPED_JSON}"
	fi

	# NOTE: alwaysEnabled should be the only attribute in this json file which
	# really matters, since it is the only attribute, which is checked for
	# which app can be disabled or not.
	# defaultEnabled is only used during installation, but not for updates.

	DISABLED_APPS=$(read_app_list "${DISABLED_APPS_FILE}")
	ALWAYS_ENABLED_APPS=$(read_app_list "${ALWAYS_ENABLED_APPS_FILE}")

	echo "Remove apps from 'shipped' list ..."
	for app in ${DISABLED_APPS}; do
		unship_app "${app}"
	done

	if [ -n "${ALWAYS_ENABLED_APPS}" ]; then
		echo "Add apps to 'alwaysEnabled' list ..."
		for app in ${ALWAYS_ENABLED_APPS}; do
			ship_app "${app}"
		done
	fi
}

main
