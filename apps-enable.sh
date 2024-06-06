#!/bin/sh

# This script assumes to be located in /IONOS as submodule within the Nextcloud server
# repository.

BDIR="$( dirname "${0}" )"

NEXTCLOUD_DIR="${BDIR}/.."
APPS_DIR="${NEXTCLOUD_DIR}/apps-external"

ooc() {
	php "${NEXTCLOUD_DIR}/occ" \
		"${@}"
}

fail() {
	echo "${*}"
	exit 1
}


main() {
	if [ ! -d "${APPS_DIR}" ]; then
		fail "Apps directory does not exist: $( readlink -f "${APPS_DIR}" )"
	fi

	echo "Enable apps in folder $APPS_DIR ..."

	for app in $( find "${APPS_DIR}" -mindepth 1 -maxdepth 1 -type d); do
		app_name="$( basename "${app}" )"
		echo "Enable app '${app_name}' ..."

		if ! ooc app:enable "${app_name}"
		then
			fail "Enabling app \"${app_name}\" failed."
		fi
	done
}

main
