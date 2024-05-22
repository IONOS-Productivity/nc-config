#!/bin/sh

# This script assumes to be located in /IONOS as submodule within the Nextcloud server
# repository.

# Since this script modifies the shipped.json file, it should not be executed  for every
# nextcloud pod in K8s. Also, since we do not use any pvc it would need to be applied for
# each nc-pod individually. Therefore this script should be executed during the image
# build.

BDIR="$( dirname "${0}" )"

. "${BDIR}"/enabled-apps.inc.sh

ooc() {
	php occ \
		"${@}"
}

fail() {
	echo "${*}"
	exit 1
}

main() {
	if ! which jq >/dev/null 2>&1; then
		fail "Error: jq is required"
	fi

	echo "Add apps to 'shipped' list ..."

	for app in ${ENABLED_APPS}; do
		echo "Enable app '${app}' ..."
		ooc app:enable "${app}"
	done
}

main
