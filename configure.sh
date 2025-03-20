#!/bin/sh

BDIR="$( dirname "${0}" )"
NEXTCLOUD_DIR="${BDIR}/.."
FAVICON_DIR=$(cd "${NEXTCLOUD_DIR}/apps-custom/nc_theming/img" && pwd)
ADMIN_USERNAME=${ADMIN_USERNAME:-admin}
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.net}

. ${BDIR}/disabled-apps.inc.sh

ooc() {
	php occ \
		"${@}"
}

fail() {
	echo "${*}"
	exit 1
}

checks() {
	if ! which php >/dev/null 2>&1; then
		fail "Error: php is required"
	fi
}

config_server() {
	echo "Configure NextCloud basics"

	ooc config:system:set lookup_server --value=""
	ooc user:setting "${ADMIN_USERNAME}" settings email "${ADMIN_EMAIL}"
	# array of providers to be used for unified search
	ooc config:app:set --value '["files"]' --type array core unified_search.providers_allowed
}

config_ui() {
	echo "Configure theming"

	ooc theming:config name "HiDrive Next"
	ooc theming:config slogan "powered by IONOS"
	ooc theming:config imprintUrl " "
	ooc theming:config privacyUrl " "
	ooc theming:config primary_color "#003D8F"
	ooc theming:config disable-user-theming yes
	ooc theming:config favicon "${FAVICON_DIR}/favicon.ico"
	ooc config:app:set theming backgroundMime --value backgroundColor

	IONOS_HOMEPAGE=$(ooc config:system:get ionos_homepage)
	if [ -n "${IONOS_HOMEPAGE}" ]; then
		ooc theming:config url "${IONOS_HOMEPAGE}"
	fi
}

configure_app_nc_ionos_processes() {
	echo "Configure nc_ionos_processes app"

	if [ -z "${IONOS_PROCESSES_API_URL}" ] || [ -z "${IONOS_PROCESSES_USER}" ] || [ -z "${IONOS_PROCESSES_PASS}" ]; then
		echo "\033[1;33mWarning: IONOS_PROCESSES_API_URL, IONOS_PROCESSES_USER or IONOS_PROCESSES_PASS not set, skipping configuration of nc_ionos_processes app\033[0m"
		return
	fi

	ooc config:app:set --value "${IONOS_PROCESSES_API_URL}" --type string nc_ionos_processes ionos_mail_base_url
	ooc config:app:set --value "${IONOS_PROCESSES_USER}" --type string nc_ionos_processes basic_auth_user
	ooc config:app:set --value "${IONOS_PROCESSES_PASS}" --sensitive --type string nc_ionos_processes basic_auth_pass
}

config_apps() {
	echo "Configure apps ..."

	echo "Configure viewer app"
	ooc config:app:set --value yes --type string viewer always_show_viewer

	echo "Disable federated sharing"
	# To disable entering the user@host ID of an external Nextcloud instance
	# in the (uncustomized) search input field of the share panel
	ooc config:app:set --value no files_sharing outgoing_server2server_share_enabled
	ooc config:app:set --value no files_sharing incoming_server2server_share_enabled
	ooc config:app:set --value no files_sharing outgoing_server2server_group_share_enabled
	ooc config:app:set --value no files_sharing incoming_server2server_group_share_enabled
	ooc config:app:set --value no files_sharing lookupServerEnabled
	ooc config:app:set --value no files_sharing lookupServerUploadEnabled

	echo "Configure internal share settings"
	# To limit user and group display in the username search field of the
	# Share panel to list only users with the same group. Groups should not
	# "see" each other. Users in one contract are part of one group.
	ooc config:app:set --value="yes" core shareapi_only_share_with_group_members
	ooc config:app:set --value='["admin"]' core shareapi_only_share_with_group_members_exclude_group_list

	configure_app_nc_ionos_processes

	echo "Configure files app"
	ooc config:app:set --value yes files crop_image_previews
	ooc config:app:set --value yes files show_hidden
	ooc config:app:set --value yes files sort_favorites_first
	ooc config:app:set --value yes files sort_folders_first
	ooc config:app:set --value no files grid_view
	ooc config:app:set --value no files folder_tree
}

disable_app() {
	# Disable app and check if it was disabled
	# Fail if disabling the app failed
	#
	app_name="${1}"
	echo "Disable app '${app_name}' ..."

		if ! ooc app:disable "${app_name}"
		then
			fail "Disable app \"${app_name}\" failed."
		fi
}

disable_apps() {
	echo "Disable apps"

	_enabled_apps=$(./occ app:list --enabled --output json | jq -j '.enabled | keys | join("\n")')
	_disabled_apps_count=0

	for app_name in ${DISABLED_APPS}; do
		printf "Checking app: %s" "${app_name}"
		if echo "${_enabled_apps}" | grep -q -w "${app_name}"; then
			echo " - currently enabled - disabling"
			disable_app "${app_name}"
			_disabled_apps_count=$(( _disabled_apps_count + 1 ))
		else
			echo " - not enabled - skip"
		fi
	done

	echo "Disabled ${_disabled_apps_count} apps."
}

add_config_partials() {
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
	checks

	local status="$( ooc status 2>/dev/null | grep 'installed: ' | sed -r 's/^.*installed: (.+)$/\1/' )"

	# Parse validation
	if [ "${status}" != "true" ] && [ "${status}" != false ]; then
		echo "Error testing Nextcloud status. This is the output of occ status:"
		ooc status
		exit 1
	elif [ "${status}" != "true" ]; then
		echo "Nextcloud is not installed, abort"
		exit 1
	fi

	add_config_partials
	config_server
	config_apps
	config_ui
	disable_apps
}

main "${@}"
