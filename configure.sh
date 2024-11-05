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

	if ! which jq >/dev/null 2>&1; then
		fail "Error: jq is required"
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

	ooc theming:config name "EasyStorage"
	ooc theming:config color "#003D8F"
	ooc theming:config disable-user-theming yes
	ooc config:app:set theming backgroundMime --value backgroundColor
	ooc config:system:set defaultapp --value files
}

config_apps() {
	echo "Configure apps"
	ooc config:app:set --value yes --type string viewer always_show_viewer
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

	# Redirecting jq's stderr to drop parser error message that we can test for it
	local status="$( ooc status --output json 2>/dev/null | jq '.installed' 2>/dev/null )"

	if [ "${status}" = "" ]; then
		echo "Error testing Nextcloud status. This is the output of occ status:"
		ooc status
		exit 1
	fi

	if [ "${status}" != "true" ]; then
		echo "NextCloud is not installed, abort"
		exit 1
	fi

	add_config_partials
	config_server
	config_apps
	config_ui
}

main "${@}"
