#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2025 STRATO GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

NEXTCLOUD_ROOT_DIR="/var/www/html"

# Log fatal error message and exit with failure code
# Usage: log_fatal <message>
log_fatal() {
	echo "\033[1;31m[x] Fatal Error: ${*}\033[0m" >/dev/stderr
	exit 1
}

# Log warning message
# Usage: log_warning <message>
log_warning() {
	echo "\033[1;33m[w] Warning: ${*}\033[0m" >/dev/stderr
}

# Validate required environment variables
# Usage: validate_env_vars <var1> <var2> ...
# Returns: 0 if all variables are set, 1 otherwise
validate_env_vars() {
	_validation_failed=false

	for _var in "${@}"; do
		eval "_value=\${${_var}}"
		if [ -z "${_value}" ]; then
			log_warning "${_var} environment variable is not set"
			_validation_failed=true
		fi
	done

	if [ "${_validation_failed}" = "true" ]; then
		return 1
	fi
	return 0
}

write_config_file() {
	config="${NEXTCLOUD_ROOT_DIR}/config/object-store.config.php"

	# Note: backslashes require double escaping due to shell (\\ -> \\\\)
	# Heredoc body is at column 0 and uses tabs for PHP indentation to keep
	# editorconfig-checker happy (the dash-form <<-EOF would strip those tabs).
	cat >"${config}" <<EOF
<?php
\$CONFIG = [
	// https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/primary_storage.html
	'objectstore' => [
		'class' => '\\\\OC\\\\Files\\\\ObjectStore\\\\S3',
		'arguments' => [
			'autocreate' => false,
			'bucket' => '${ENC_OBJECT_STORAGE_BUCKET_NAME}',
			'region' => '${ENC_OBJECT_STORAGE_REGION}',
			'hostname' => '${ENC_OBJECT_STORAGE_HOSTNAME}',
			'port' => ${ENC_OBJECT_STORAGE_PORT},
			'use_ssl' => ${use_ssl_value},
			'key' => '${ENC_OBJECT_STORAGE_ACCESS_KEY}',
			'secret' => '${ENC_OBJECT_STORAGE_SECRET}',
			'objectPrefix' => 'urn:oid:',
			'use_path_style' => ${use_path_style_value},
		],
	],
];
EOF
}

main() {
	# Configure object store
	#
	# Expects these environment variables:
	#
	# - ENC_OBJECT_STORAGE_BUCKET_NAME
	# - ENC_OBJECT_STORAGE_ACCESS_KEY
	# - ENC_OBJECT_STORAGE_SECRET
	# - ENC_OBJECT_STORAGE_REGION
	# - ENC_OBJECT_STORAGE_HOSTNAME
	# - ENC_OBJECT_STORAGE_PORT
	# - ENC_OBJECT_STORAGE_USE_SSL (default: true)
	# - ENC_OBJECT_STORAGE_USE_PATH_STYLE (default: false)

	use_ssl_value="true"
	use_path_style_value="false"

	if [ ! -x "occ" ]; then
		log_fatal "occ command not found, are you in Nextcloud's root dir?"
	fi

	if ! validate_env_vars \
		ENC_OBJECT_STORAGE_BUCKET_NAME \
		ENC_OBJECT_STORAGE_ACCESS_KEY \
		ENC_OBJECT_STORAGE_SECRET \
		ENC_OBJECT_STORAGE_REGION \
		ENC_OBJECT_STORAGE_HOSTNAME \
		ENC_OBJECT_STORAGE_PORT; then
		log_fatal "required object store environment variables are not set"
	fi

	if [ -n "${ENC_OBJECT_STORAGE_USE_SSL}" ] && [ "${ENC_OBJECT_STORAGE_USE_SSL}" != "true" ] && [ "${ENC_OBJECT_STORAGE_USE_SSL}" != "false" ]; then
		log_fatal "ENC_OBJECT_STORAGE_USE_SSL, if set should either be true or false"
	fi

	if [ -n "${ENC_OBJECT_STORAGE_USE_PATH_STYLE}" ] && [ "${ENC_OBJECT_STORAGE_USE_PATH_STYLE}" != "true" ] && [ "${ENC_OBJECT_STORAGE_USE_PATH_STYLE}" != "false" ]; then
		log_fatal "ENC_OBJECT_STORAGE_USE_PATH_STYLE, if set should either be true or false"
	fi

	if [ "${ENC_OBJECT_STORAGE_USE_SSL}" = "false" ]; then
		use_ssl_value="false"
	fi

	if [ "${ENC_OBJECT_STORAGE_USE_PATH_STYLE}" = "true" ]; then
		use_path_style_value="true"
	fi

	echo "Writing ${config} ..."

	if ! write_config_file; then
		log_fatal "Error writing the object store config: ${config}"
	fi

	echo "Object store config written: ${config}"
}

main "${@}"
