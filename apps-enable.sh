#!/bin/sh

# This script assumes to be located in /IONOS as submodule within the Nextcloud server
# repository.

BDIR="$( dirname "${0}" )"

NEXTCLOUD_DIR="${BDIR}/.."

ooc() {
	php "${NEXTCLOUD_DIR}/occ" \
		"${@}"
}

fail() {
	echo "${*}"
	exit 1
}

enable_apps() {
	# Enable app in given directory
	#
	apps_dir="${1}"

	if [ ! -d "${apps_dir}" ]; then
		fail "Apps directory does not exist: $( readlink -f "${apps_dir}" )"
	fi

	echo "Enable apps in folder ${apps_dir} ..."

	for app in $( find "${apps_dir}" -mindepth 1 -maxdepth 1 -type d | sort); do
		app_name="$( basename "${app}" )"
		echo "Enable app '${app_name}' ..."

		if ! ooc app:enable "${app_name}"
		then
			fail "Enabling app \"${app_name}\" failed."
		fi
	done
}

main() {
	enable_apps "${NEXTCLOUD_DIR}/apps-external"
	enable_apps "${NEXTCLOUD_DIR}/apps-custom"
}

main
