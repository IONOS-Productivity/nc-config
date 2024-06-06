#!/bin/sh

# This script assumes to be located in /IONOS as submodule within the Nextcloud server
# repository.

BDIR="$( dirname "${0}" )"

NEXTCLOUD_DIR="${BDIR}/.."
APPS_DIR="${NEXTCLOUD_DIR}/apps-external"

ooc() {
	php occ \
		"${@}"
}

fail() {
	echo "${*}"
	exit 1
}

download_verify_install_app() {
	# Download file from the supplied URL, check the supplied SHA256 and install
	#
	# name - app name
	# download url - app name
	# sha - the SHA256 of the file

	name="${1}"
	download_url="${2}"
	sha="${3}"

	app_dir="${APPS_DIR}/${name}"
	temp_package_file="$( mktemp -t "${name}-XXXXXX.tar.gz" )"
	temp_sha_file="$( mktemp )"

	echo "${sha} ${temp_package_file}" > "${temp_sha_file}"

	if [ ! -d "${app_dir}" ]; then
		mkdir "${app_dir}" || fail "Error creating the app directory for ${name}."
	fi

	if [ -n "$( find "${app_dir}" -mindepth 1 )" ]; then
		fail "App directory not empty: ${app_dir}"
	fi

	wget -O "${temp_package_file}" "${download_url}" || fail "Downloading ${name} from ${download_url} failed."

	echo "Verify SHA256 ..."

	sha256sum -c "${temp_sha_file}" || fail "Bad checksum"

	echo "Unpack to ${app_dir} ..."
	tar --strip-components 1 -xzf "${temp_package_file}" -C "${app_dir}" || fail "Unpacking ${temp_package_file} failed."

	rm "${temp_package_file}" "${temp_sha_file}" || echo "Removing temporary download file ${temp_package_file} failed. Continuing."
}

download_oidc() {
	name="user_oidc"
	version="v5.0.2"
	download_url="https://github.com/nextcloud-releases/${name}/releases/download/${version}/${name}-${version}.tar.gz"
	sha="7a6b981f3e0c388c52e658af966d27f26815e4d1175efca4db4bf975911538e8"

	echo "Install app '${name}' ${version} ..."

	download_verify_install_app "${name}" "${download_url}" "${sha}"
}

main() {
	if ! which wget >/dev/null 2>&1; then
		fail "Error: wget is required"
	fi

	if ! which sha256sum >/dev/null 2>&1; then
		fail "Error: sha256sum is required"
	fi

	if [ ! -d "${APPS_DIR}" ]; then
		fail "Apps directory does not exist: $( readlink -f "${APPS_DIR}" )"
	fi

	echo "Install and enable apps ..."

	download_oidc

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
