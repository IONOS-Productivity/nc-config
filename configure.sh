#!/bin/sh

BDIR="$( dirname "${0}" )"

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
	ooc user:setting admin settings email admin@example.net
	# array of providers to be used for unified search
	ooc config:app:set --value '["files"]' --type array core unified_search.providers_allowed
}

config_ui() {
	echo "Configure theming"

	ooc theming:config name "HiDrive Next"
	ooc theming:config primary_color "#003D8F"
	ooc theming:config disable-user-theming yes
	ooc config:app:set theming backgroundMime --value backgroundColor
	ooc config:system:set defaultapp --value files
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
	ooc config:app:set --value="no" core shareapi_only_share_with_group_members
	ooc config:app:set --value='["admin"]' core shareapi_only_share_with_group_members_exclude_group_list

	echo "Configure nc_ionos_processes app"

	if [ -z "${IONOS_PROCESSES_API_URL}" ] || [ -z "${IONOS_PROCESSES_USER}" ] || [ -z "${IONOS_PROCESSES_PASS}" ]; then
		echo "Warning: IONOS_PROCESSES_API_URL, IONOS_PROCESSES_USER or IONOS_PROCESSES_PASS not set, skipping configuration of nc_ionos_processes app"
		return
	fi

	ooc config:app:set --value "${IONOS_PROCESSES_API_URL}" --type string nc_ionos_processes ionos_mail_base_url
	ooc config:app:set --value "${IONOS_PROCESSES_USER}" --type string nc_ionos_processes basic_auth_user
	ooc config:app:set --value "${IONOS_PROCESSES_PASS}" --type string nc_ionos_processes basic_auth_pass
	
	echo "Configure files app"
	ooc config:app:set --value yes files crop_image_previews
	ooc config:app:set --value yes files show_hidden
	ooc config:app:set --value yes files sort_favorites_first
	ooc config:app:set --value yes files sort_folders_first
	ooc config:app:set --value no files grid_view
	ooc config:app:set --value no files folder_tree
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
}

main "${@}"
