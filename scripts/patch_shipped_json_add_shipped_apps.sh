#!/bin/bash
set -euo pipefail

# SPDX-FileCopyrightText: 2025 STRATO GmbH
# SPDX-License-Identifier: AGPL-3.0-or-later

################################################################################
# Patch shipped.json - Add Apps Script
################################################################################
#
# DESCRIPTION:
#   This script patches the core/shipped.json file by adding apps from
#   specified app directories to the shippedApps array. It ensures that:
#   1. Apps are added to the end of the array for better diff visibility
#   2. Duplicate entries are prevented (uniqueness is maintained)
#   3. JSON structure remains valid
#
# LOCATION:
#   This script is located in /IONOS/scripts/ as part of the IONOS submodule
#   within the Nextcloud server repository.
#
# EXECUTION CONTEXT:
#   ⚠️  IMPORTANT: This script should be executed during the Docker image build
#   process, NOT at runtime in Kubernetes pods.
#
# USAGE:
#   ./scripts/patch_shipped_json_add_shipped_apps.sh <app_folder1> [app_folder2] ...
#
#   Example:
#   ./scripts/patch_shipped_json_add_shipped_apps.sh apps-external apps-custom
#
# ARGUMENTS:
#   $@ - One or more app folder names relative to the Nextcloud root directory
#
# PREREQUISITES:
#   - jq (JSON processor) must be installed
#   - bash must be available
#   - ../core/shipped.json must exist and be valid JSON
#   - Specified app folders must exist
#
# OUTPUT:
#   - Modifies ../core/shipped.json in place
#   - Logs progress and results to stdout/stderr
#
# EXIT CODES:
#   0 - Success
#   1 - Fatal error (missing dependencies, invalid files, or processing errors)
#
# AUTHOR: IONOS Nextcloud Customization Team
# LICENSE: See LICENSES/ directory
#
################################################################################

# Configuration: Base directory and file paths
BDIR="$(dirname "${0}")"
SHIPPED_JSON="${BDIR}/../../core/shipped.json"

################################################################################
# Logging Functions
################################################################################

log_info() {
	printf "\033[0;32m[✓]\033[0m %s\n" "${*}"
}

log_warn() {
	printf "\033[0;33m[!]\033[0m %s\n" "${*}" >&2
}

log_fatal() {
	printf "\033[1;31m[✗]\033[0m Fatal Error: %s\n" "${*}" >&2
	exit 1
}

################################################################################
# Utility Functions
################################################################################

command_exists() {
	command -v "${1}" >/dev/null 2>&1
}

################################################################################
# Core Functions
################################################################################

# Validate that shipped.json is valid JSON
# Performs a validation check on shipped.json using jq
# Usage: validate_shipped_json
# Exit: Calls log_fatal if JSON is invalid
validate_shipped_json() {
	if ! jq empty "${SHIPPED_JSON}" 2>/dev/null; then
		log_fatal "Invalid JSON in ${SHIPPED_JSON}"
	fi
}

# Add apps from a directory to shippedApps array
# Adds all apps from the specified directory to the shippedApps array
# while maintaining uniqueness and adding to the end of the array
# Usage: ship_apps_from_directory <app_folder_path>
# Arguments:
#   $1 - Path to the app folder (relative or absolute)
# Side Effects:
#   - Modifies shipped.json in place
#   - Logs success messages for each added app
ship_apps_from_directory() {
	local app_folder="${1}"
	local app_folder_path="${BDIR}/../../${app_folder}"
	local temp_file="${SHIPPED_JSON}.tmp"
	local added_count=0
	local skipped_count=0

	# Check if directory exists
	if [ ! -d "${app_folder_path}" ]; then
		log_warn "App folder does not exist: ${app_folder_path}"
		return
	fi

	log_info "Processing apps from '${app_folder}'..."

	# Iterate over each subdirectory in the app folder
	for app_path in "${app_folder_path}"/*; do
		# Skip if not a directory
		if [ ! -d "${app_path}" ]; then
			continue
		fi

		# Extract app name from path
		app_name=$(basename "${app_path}")

		# Check if app already exists in shippedApps
		if jq -e --arg app "${app_name}" '.shippedApps | index($app)' "${SHIPPED_JSON}" >/dev/null 2>&1; then
			log_info "App '${app_name}' already in shippedApps, skipping"
			skipped_count=$((skipped_count + 1))
			continue
		fi

		# Add app to the end of shippedApps array
		if ! jq --arg app "${app_name}" \
			'.shippedApps += [$app]' \
			"${SHIPPED_JSON}" > "${temp_file}"; then
			log_fatal "Failed to add app '${app_name}' with jq"
		fi

		# Atomically replace the original file
		mv "${temp_file}" "${SHIPPED_JSON}"
		log_info "Added app '${app_name}' to shippedApps"
		added_count=$((added_count + 1))
	done

	log_info "Processed ${app_folder}: ${added_count} apps added, ${skipped_count} apps skipped (already present)"
}

main() {
	# Check prerequisites
	if ! command_exists jq; then
		log_fatal "jq is required but not installed"
	fi

	if [ ! -f "${SHIPPED_JSON}" ]; then
		log_fatal "Shipped JSON file not found: ${SHIPPED_JSON}"
	fi

	# Check if at least one app folder argument was provided
	if [ $# -eq 0 ]; then
		log_fatal "Usage: $(basename "$0") <app_folder1> [app_folder2] ..."
	fi

	# Validate shipped.json before processing
	validate_shipped_json

	log_info "Starting to add apps to shippedApps array..."

	# Process each app folder provided as argument
	for app_folder in "$@"; do
		ship_apps_from_directory "${app_folder}"
	done

	# Validate shipped.json after processing to ensure we didn't corrupt it
	validate_shipped_json

	log_info "Successfully completed shipping apps from specified folders"
}

# Execute main function with all arguments
main "$@"
