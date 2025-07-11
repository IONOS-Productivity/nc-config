#!/bin/sh

#===============================================================================
# HiDrive Next Configuration Script
#===============================================================================
# This script configures a HiDrive Next instance with IONOS-specific settings.
#
# Features:
# - Server basic configuration (lookup server, admin email, search providers)
# - Theming and branding setup for IONOS HiDrive Next
# - App configuration (viewer, sharing, files, DAV)
# - Integration setup (IONOS processes, serverinfo, Collabora)
# - Selective app disabling based on configuration
# - Configuration partials for app paths
#
# Environment Variables:
# - ADMIN_USERNAME: Admin username (default: admin)
# - ADMIN_EMAIL: Admin email (default: admin@example.net)
# - IONOS_PROCESSES_API_URL: API URL for IONOS processes
# - IONOS_PROCESSES_USER: Username for IONOS processes API
# - IONOS_PROCESSES_PASS: Password for IONOS processes API
# - NC_APP_SERVERINFO_TOKEN: Token for serverinfo app
# - COLLABORA_HOST: Collabora server host URL
# - COLLABORA_EDIT_GROUPS: Groups allowed to edit in Collabora
# - COLLABORA_SELF_SIGNED: Set to "true" for self-signed certificates
#
# Usage: ./configure.sh
#===============================================================================

# Script configuration and constants
SCRIPT_DIR="$( dirname "${0}" )"
readonly SCRIPT_DIR
NEXTCLOUD_DIR="${SCRIPT_DIR}/.."
readonly NEXTCLOUD_DIR
FAVICON_DIR=$(cd "${NEXTCLOUD_DIR}/apps-custom/nc_theming/img" && pwd)
readonly FAVICON_DIR
readonly ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
readonly ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.net}

# Load disabled apps configuration
. ${SCRIPT_DIR}/disabled-apps.inc.sh

#===============================================================================
# Utility Functions
#===============================================================================

# Execute NextCloud OCC command with error handling
# Usage: execute_occ_command <command> [args...]
execute_occ_command() {
	php occ \
		"${@}"
}

fail() {
	echo "${*}"
	exit 1
}

# Check if required dependencies are available
# Usage: check_dependencies
check_dependencies() {
	if ! which php >/dev/null 2>&1; then
		fail "Error: php is required but not found in PATH"
	fi
}

#===============================================================================
# Configuration Functions
#===============================================================================

# Configure basic HiDrive Next server settings
# Usage: configure_server_basics
configure_server_basics() {
	echo "Configuring HiDrive Next server basics..."

	execute_occ_command config:system:set lookup_server --value=""
	execute_occ_command user:setting "${ADMIN_USERNAME}" settings email "${ADMIN_EMAIL}"
	# array of providers to be used for unified search
	execute_occ_command config:app:set --value '["files"]' --type array core unified_search.providers_allowed
}

# Configure HiDrive Next theming and branding
# Usage: configure_theming
configure_theming() {
	echo "Configuring HiDrive Next theming..."

	execute_occ_command theming:config name "HiDrive Next"
	execute_occ_command theming:config slogan "powered by IONOS"
	execute_occ_command theming:config imprintUrl " "
	execute_occ_command theming:config privacyUrl " "
	execute_occ_command theming:config primary_color "#003D8F"
	execute_occ_command theming:config disable-user-theming yes
	execute_occ_command theming:config favicon "${FAVICON_DIR}/favicon.ico"
	execute_occ_command config:app:set theming backgroundMime --value backgroundColor

	# Set homepage URL if configured
	IONOS_HOMEPAGE=$(execute_occ_command config:system:get ionos_homepage)
	if [ -n "${IONOS_HOMEPAGE}" ]; then
		execute_occ_command theming:config url "${IONOS_HOMEPAGE}"
	fi
}

# Configure IONOS processes app with API credentials
# Usage: configure_ionos_processes_app
configure_ionos_processes_app() {
	echo "Configuring nc_ionos_processes app..."

	# Check required environment variables
	if [ -z "${IONOS_PROCESSES_API_URL}" ] || [ -z "${IONOS_PROCESSES_USER}" ] || [ -z "${IONOS_PROCESSES_PASS}" ]; then
		echo "\033[1;33mWarning: IONOS_PROCESSES_API_URL, IONOS_PROCESSES_USER or IONOS_PROCESSES_PASS not set, skipping configuration of nc_ionos_processes app\033[0m"
		return
	fi

	execute_occ_command config:app:set --value "${IONOS_PROCESSES_API_URL}" --type string nc_ionos_processes ionos_mail_base_url
	execute_occ_command config:app:set --value "${IONOS_PROCESSES_USER}" --type string nc_ionos_processes basic_auth_user
	execute_occ_command config:app:set --value "${IONOS_PROCESSES_PASS}" --sensitive --type string nc_ionos_processes basic_auth_pass
}

# Configure serverinfo app with authentication token
# Usage: configure_serverinfo_app
configure_serverinfo_app() {
	echo "Configuring serverinfo app..."

	if [ -z "${NC_APP_SERVERINFO_TOKEN}" ]; then
		echo "\033[1;33mWarning: NC_APP_SERVERINFO_TOKEN not set, skipping configuration of serverinfo app\033[0m"
		return
	fi

	execute_occ_command config:app:set serverinfo token --value "${NC_APP_SERVERINFO_TOKEN}"
}

# Configure Collabora/richdocuments integration
# Usage: configure_collabora_app
configure_collabora_app() {
	echo "Configuring Collabora integration..."
	# Disable app initially
	execute_occ_command app:disable richdocuments

	# Validate required environment variables
	if ! [ "${COLLABORA_HOST}" ] ; then
		fail "COLLABORA_HOST environment variable is not set"
	fi

	if ! [ "${COLLABORA_EDIT_GROUPS}" ] ; then
		fail "COLLABORA_EDIT_GROUPS environment variable is not set"
	fi

	# Configure and enable Collabora
	execute_occ_command app:enable richdocuments
	execute_occ_command config:app:set richdocuments wopi_url --value="${COLLABORA_HOST}"
	execute_occ_command config:app:set richdocuments public_wopi_url --value="${COLLABORA_HOST}"
	execute_occ_command config:app:set richdocuments enabled --value='yes'

	# Configure SSL certificate verification
	if [ "${COLLABORA_SELF_SIGNED}" = "true" ] ; then
		execute_occ_command config:app:set richdocuments disable_certificate_verification --value="yes"
	else
		execute_occ_command config:app:set richdocuments disable_certificate_verification --value="no"
	fi

	execute_occ_command config:app:set richdocuments edit_groups --value="${COLLABORA_EDIT_GROUPS}"
	execute_occ_command app:enable richdocuments

	execute_occ_command richdocuments:activate-config
}

config_apps() {
	echo "Configure apps ..."

	echo "Configure viewer app"
	execute_occ_command config:app:set --value yes --type string viewer always_show_viewer

	echo "Disable federated sharing"
	# To disable entering the user@host ID of an external Nextcloud instance
	# in the (uncustomized) search input field of the share panel
	execute_occ_command config:app:set --value no files_sharing outgoing_server2server_share_enabled
	execute_occ_command config:app:set --value no files_sharing incoming_server2server_share_enabled
	execute_occ_command config:app:set --value no files_sharing outgoing_server2server_group_share_enabled
	execute_occ_command config:app:set --value no files_sharing incoming_server2server_group_share_enabled
	execute_occ_command config:app:set --value no files_sharing lookupServerEnabled
	execute_occ_command config:app:set --value no files_sharing lookupServerUploadEnabled

	echo "Configure internal share settings"
	# To limit user and group display in the username search field of the
	# Share panel to list only users with the same group. Groups should not
	# "see" each other. Users in one contract are part of one group.
	execute_occ_command config:app:set --value="yes" core shareapi_only_share_with_group_members
	execute_occ_command config:app:set --value="no" core shareapi_allow_group_sharing
	execute_occ_command config:app:set --value='["admin"]' core shareapi_only_share_with_group_members_exclude_group_list

	configure_ionos_processes_app
	configure_serverinfo_app
	configure_collabora_app

	echo "Configure files app"
	execute_occ_command config:app:set --value yes files crop_image_previews
	execute_occ_command config:app:set --value yes files show_hidden
	execute_occ_command config:app:set --value yes files sort_favorites_first
	execute_occ_command config:app:set --value yes files sort_folders_first
	execute_occ_command config:app:set --value no files grid_view
	execute_occ_command config:app:set --value no files folder_tree

	echo "Configure DAV"
	execute_occ_command config:app:set dav system_addressbook_exposed --value="no"
}

#===============================================================================
# App Management Functions
#===============================================================================

# Disable a single HiDrive Next app with error handling
# Usage: disable_single_app <app_name>
disable_single_app() {
	# Disable app and check if it was disabled
	# Fail if disabling the app failed
	#
	app_name="${1}"
	echo "Disabling app '${app_name}'..."

		if ! execute_occ_command app:disable "${app_name}"
		then
			fail "Disable app \"${app_name}\" failed."
		fi
}

# Disable multiple apps based on the DISABLED_APPS list
# Usage: disable_configured_apps
disable_configured_apps() {
	echo "Processing app disabling..."

	_enabled_apps=$(./occ app:list --enabled --output json | jq -j '.enabled | keys | join("\n")')
	_disabled_apps_count=0

	for app_name in ${DISABLED_APPS}; do
		printf "Checking app: %s" "${app_name}"
		if echo "${_enabled_apps}" | grep -q -w "${app_name}"; then
			echo " - currently enabled - disabling"
			disable_single_app "${app_name}"
			_disabled_apps_count=$(( _disabled_apps_count + 1 ))
		else
			echo " - not enabled - skip"
		fi
	done

	echo "Disabled ${_disabled_apps_count} apps."
}

#===============================================================================
# Configuration Setup Functions
#===============================================================================

# Add HiDrive Next configuration partials for app paths
# Usage: setup_config_partials
setup_config_partials() {
	echo "Setting up configuration partials..."

	cat >"${SCRIPT_DIR}"/../config/app-paths.config.php <<-'EOF'
		<?php
		$CONFIG = [
		  'apps_paths' => [
		    [
		      'path' => '/var/www/html/apps',
		      'url' => '/apps',
		      'writable' => true,
		    ],
		    [
		      'path' => '/var/www/html/apps-custom',
		      'url' => '/apps-custom',
		      'writable' => true,
		    ],
		    [
		      'path' => '/var/www/html/apps-external',
		      'url' => '/apps-external',
		      'writable' => true,
		    ],
		  ],
		];
	EOF
}

#===============================================================================
# Main Execution Function
#===============================================================================

# Main function to orchestrate HiDrive Next configuration
# Usage: main [args...]
main() {
	echo "Starting HiDrive Next configuration process..."

	# Perform initial checks
	check_dependencies

	_main_status="$( execute_occ_command status 2>/dev/null | grep 'installed: ' | sed -r 's/^.*installed: (.+)$/\1/' )"

	# Parse validation
	if [ "${_main_status}" != "true" ] && [ "${_main_status}" != false ]; then
		echo "Error testing Nextcloud install status. This is the output of occ status:"
		execute_occ_command status
		exit 1
	elif [ "${_main_status}" != "true" ]; then
		echo "Nextcloud is not installed, abort"
		exit 1
	fi

	# Execute configuration steps
	setup_config_partials
	configure_server_basics
	config_apps
	configure_theming
	disable_configured_apps

	echo "HiDrive Next configuration completed successfully!"
}

# Execute main function with all script arguments
main "${@}"
