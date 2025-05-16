#!/bin/sh

# This script assumes to be located in /IONOS as submodule within the Nextcloud server
# repository.

# Since this script modifies the shipped.json file, it should not be executed  for every
# nextcloud pod in K8s. Also, since we do not use any pvc it would need to be applied for
# each nc-pod individually. Therefore this script should be executed during the image
# build.

BDIR="$( dirname ${0} )"

SHIPPED_JSON="${BDIR}/../core/shipped.json"

. ${BDIR}/disabled-apps.inc.sh

fail() {
	echo "${*}"
	exit 1
}

main() {
	if ! which jq 2>&1 >/dev/null; then
		fail "Error: jq is required"
	fi

	# alwaysEnabled should be the only attribute in this json file which really matters,
	# since it is the only attribute, which is checked for which app can be disabled or not.
	# defaultEnabled is only used during installation, but not for updates.

	echo "Remove apps from 'shipped' list ..."

	for app in ${DISABLED_APPS}; do
		echo "Unship app '${app}' ..."
		cat ${SHIPPED_JSON} \
			| jq --arg toUnforce "${app}" 'del(.defaultEnabled[] | select(. == $toUnforce))' \
			| jq --arg toUnforce "${app}" 'del(.alwaysEnabled[] | select(. == $toUnforce))' > ${SHIPPED_JSON}.tmp \
				&& mv --force ${SHIPPED_JSON}.tmp ${SHIPPED_JSON}
	done
}

main
