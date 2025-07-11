#!/bin/sh

BDIR="$( dirname "${0}" )"
NEXTCLOUD_DIR="${BDIR}/.."
FAVICON_DIR=$(cd "${NEXTCLOUD_DIR}/apps-custom/nc_theming/img" && pwd)
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.net}

. ${BDIR}/disabled-apps.inc.sh

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

check_dependencies() {
	if ! which php >/dev/null 2>&1; then
		fail "Error: php is required"
	fi
}

configure_server_basics() {
	echo "Configure NextCloud basics"

	execute_occ_command config:system:set lookup_server --value=""
	execute_occ_command user:setting "${ADMIN_USERNAME}" settings email "${ADMIN_EMAIL}"
	# array of providers to be used for unified search
	execute_occ_command config:app:set --value '["files"]' --type array core unified_search.providers_allowed
}

configure_theming() {
	echo "Configure theming"

	execute_occ_command theming:config name "HiDrive Next"
	execute_occ_command theming:config slogan "powered by IONOS"
	execute_occ_command theming:config imprintUrl " "
	execute_occ_command theming:config privacyUrl " "
	execute_occ_command theming:config primary_color "#003D8F"
	execute_occ_command theming:config disable-user-theming yes
	execute_occ_command theming:config favicon "${FAVICON_DIR}/favicon.ico"
	execute_occ_command config:app:set theming backgroundMime --value backgroundColor

	IONOS_HOMEPAGE=$(execute_occ_command config:system:get ionos_homepage)
	if [ -n "${IONOS_HOMEPAGE}" ]; then
		execute_occ_command theming:config url "${IONOS_HOMEPAGE}"
	fi
}

configure_ionos_processes_app() {
	echo "Configure nc_ionos_processes app"

	if [ -z "${IONOS_PROCESSES_API_URL}" ] || [ -z "${IONOS_PROCESSES_USER}" ] || [ -z "${IONOS_PROCESSES_PASS}" ]; then
		echo "\033[1;33mWarning: IONOS_PROCESSES_API_URL, IONOS_PROCESSES_USER or IONOS_PROCESSES_PASS not set, skipping configuration of nc_ionos_processes app\033[0m"
		return
	fi

	execute_occ_command config:app:set --value "${IONOS_PROCESSES_API_URL}" --type string nc_ionos_processes ionos_mail_base_url
	execute_occ_command config:app:set --value "${IONOS_PROCESSES_USER}" --type string nc_ionos_processes basic_auth_user
	execute_occ_command config:app:set --value "${IONOS_PROCESSES_PASS}" --sensitive --type string nc_ionos_processes basic_auth_pass
}

configure_serverinfo_app() {
	echo "Configure serverinfo app"

	if [ -z "${NC_APP_SERVERINFO_TOKEN}" ]; then
		echo "\033[1;33mWarning: NC_APP_SERVERINFO_TOKEN not set, skipping configuration of serverinfo app\033[0m"
		return
	fi

	execute_occ_command config:app:set serverinfo token --value "${NC_APP_SERVERINFO_TOKEN}"
}

configure_collabora_app() {
	execute_occ_command app:disable richdocuments

	if ! [ "${COLLABORA_HOST}" ] ; then
		fail Collabora host is not set
	fi

	if ! [ "${COLLABORA_EDIT_GROUPS}" ] ; then
		fail Collabora edit groups are not set
	fi

	execute_occ_command app:enable richdocuments
	execute_occ_command config:app:set richdocuments wopi_url --value="${COLLABORA_HOST}"
	execute_occ_command config:app:set richdocuments public_wopi_url --value="${COLLABORA_HOST}"
	execute_occ_command config:app:set richdocuments enabled --value='yes'

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

disable_single_app() {
	# Disable app and check if it was disabled
	# Fail if disabling the app failed
	#
	app_name="${1}"
	echo "Disable app '${app_name}' ..."

		if ! execute_occ_command app:disable "${app_name}"
		then
			fail "Disable app \"${app_name}\" failed."
		fi
}

disable_configured_apps() {
	echo "Disable apps"

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

setup_config_partials() {
	echo "Add config partials ..."

	cat >"${BDIR}"/../config/app-paths.config.php <<-'EOF'
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

main() {
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

	setup_config_partials
	configure_server_basics
	config_apps
	configure_theming
	disable_configured_apps
}

main "${@}"
