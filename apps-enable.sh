#!/bin/sh

# This script assumes to be located in /IONOS as submodule within the Nextcloud server
# repository.

BDIR="$( dirname "${0}" )"

NEXTCLOUD_DIR="${BDIR}/.."

. ${BDIR}/enabled-core-apps.inc.sh
. ${BDIR}/disabled-apps.inc.sh

execute_occ_command() {
	php "${NEXTCLOUD_DIR}/occ" \
		"${@}"
}

fail() {
	echo "${*}" >&2
	exit 1
}

enable_app() {
	# Enable app and check if it was enabled
	# Return 1 if enabling the app failed, 0 if successful
	#
	app_name="${1}"
	echo "Enable app '${app_name}' ..."

		if ! execute_occ_command app:enable "${app_name}"
		then
			echo "ERROR: Enabling app \"${app_name}\" failed."
			return 1
		fi
		return 0
}

disable_app() {
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

enable_apps() {
	# Enable app in given directory
	#
	apps_dir="${1}"
	_enabled_apps_count=0
	_disabled_apps_count=0
	_failed_apps_count=0
	_failed_apps_list=""

	if [ ! -d "${apps_dir}" ]; then
		fail "Apps directory does not exist: $( readlink -f "${apps_dir}" )"
	fi

	_enabled_apps=$(execute_occ_command app:list --enabled --output json | jq -j '.enabled | keys | join("\n")')

	for app in $( find "${apps_dir}" -mindepth 1 -maxdepth 1 -type d | sort); do
		app_name="$( basename "${app}" )"
		printf "Checking app: %s" "${app_name}"

		if echo "${_enabled_apps}" | grep -q -w ${app_name}; then

			if echo "${DISABLED_APPS}" | grep -q -w ${app_name}; then
				echo " - currently enabled - disabling due to being in DISABLED_APPS"
				disable_app "${app_name}"
				_disabled_apps_count=$(( _disabled_apps_count + 1 ))
				continue
			fi

			echo " - already enabled - skipping"
		else

			if echo "${DISABLED_APPS}" | grep -q -w ${app_name}; then
				echo " - currently disabled - skipping due to being in DISABLED_APPS"
				continue
			fi

			echo " - currently disabled - enabling"
			if enable_app "${app_name}"; then
				_enabled_apps_count=$(( _enabled_apps_count + 1 ))
			else
				_failed_apps_count=$(( _failed_apps_count + 1 ))
				if [ -z "${_failed_apps_list}" ]; then
					_failed_apps_list="${app_name}"
				else
					_failed_apps_list="${_failed_apps_list}, ${app_name}"
				fi
			fi
		fi
	done

	echo
	echo "Enabled ${_enabled_apps_count} apps in ${apps_dir}"
	echo "Disabled ${_disabled_apps_count} apps in ${apps_dir}"
	if [ ${_failed_apps_count} -gt 0 ]; then
		fail "PANIC: Failed to enable ${_failed_apps_count} apps in ${apps_dir}: ${_failed_apps_list}"
	fi
	echo
}

enable_core_apps() {
	# Enable required core apps if they are presently disabled
	#
	_enabled_apps_count=0

	echo "Check required core apps are enabled..."

	disabled_apps=$(execute_occ_command app:list --disabled --output json | jq -j '.disabled | keys | join("\n")')

	if [ -z "${disabled_apps}" ]; then
		echo "No disabled apps found."
		exit 0
	fi

	for app in ${ENABLED_CORE_APPS}; do
		printf "Checking core app: %s" "${app}"
		if echo "${disabled_apps}" | grep -q -w ${app}; then

			if echo "${DISABLED_APPS}" | grep -q -w ${app_name}; then
				echo " - currently disabled - skipping due to being in DISABLED_APPS"
				continue
			fi

			echo " - currently disabled - enabling"
			enable_app "${app}"
			_enabled_apps_count=$(( _enabled_apps_count + 1 ))
		else
			echo " - already enabled - skip"
		fi
	done

	echo
	echo "Enabled ${_enabled_apps_count} core apps."
	echo "Done."
}

main() {
	if ! jq --version 2>&1 >/dev/null; then
		fail "Error: jq is required"
	fi

	echo "Enable all apps in 'apps-external' folder"
	enable_apps "${NEXTCLOUD_DIR}/apps-external"

	echo "Enable all apps in 'apps-custom' folder"
	enable_apps "${NEXTCLOUD_DIR}/apps-custom"

	echo "Enable all apps in 'apps' folder"
	enable_core_apps
}

main
