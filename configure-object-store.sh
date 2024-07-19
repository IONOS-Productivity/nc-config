#!/usr/bin/env sh

NEXTCLOUD_ROOT_DIR="/var/www/html"

fail() {
	echo "${*}" >/dev/stderr
	exit 1
}

write_config_file() {
	config="${NEXTCLOUD_ROOT_DIR}/config/object-store.config.php"

	# Note: backslashes require double escaping due to shell (\\ -> \\\\)
	cat >${config} <<-EOF
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
		fail "occ command not found, are you in Nextcloud's root dir?"
	fi

	if [ -z "${ENC_OBJECT_STORAGE_BUCKET_NAME}" ]; then
		fail "ENC_OBJECT_STORAGE_BUCKET_NAME not set"
	fi

	if [ -z "${ENC_OBJECT_STORAGE_ACCESS_KEY}" ]; then
		fail "ENC_OBJECT_STORAGE_ACCESS_KEY not set"
	fi

	if [ -z "${ENC_OBJECT_STORAGE_SECRET}" ]; then
		fail "ENC_OBJECT_STORAGE_SECRET not set"
	fi

	if [ -z "${ENC_OBJECT_STORAGE_REGION}" ]; then
		fail "ENC_OBJECT_STORAGE_REGION not set"
	fi

	if [ -z "${ENC_OBJECT_STORAGE_HOSTNAME}" ]; then
		fail "ENC_OBJECT_STORAGE_HOSTNAME not set"
	fi

	if [ -z "${ENC_OBJECT_STORAGE_PORT}" ]; then
		fail "ENC_OBJECT_STORAGE_PORT not set"
	fi

	if [ -n "${ENC_OBJECT_STORAGE_USE_SSL}" ] && [ "${ENC_OBJECT_STORAGE_USE_SSL}" != "true" ] && [ "${ENC_OBJECT_STORAGE_USE_SSL}" != "false" ]; then
		fail "ENC_OBJECT_STORAGE_USE_SSL, if set should either be true or false"
	fi

	if [ -n "${ENC_OBJECT_STORAGE_USE_PATH_STYLE}" ] && [ "${ENC_OBJECT_STORAGE_USE_PATH_STYLE}" != "true" ] && [ "${ENC_OBJECT_STORAGE_USE_PATH_STYLE}" != "false" ]; then
		fail "ENC_OBJECT_STORAGE_USE_PATH_STYLE, if set should either be true or false"
	fi

	if [ "${ENC_OBJECT_STORAGE_USE_SSL}" = "false" ]; then
		use_ssl_value="false"
	fi

	if [ "${ENC_OBJECT_STORAGE_USE_PATH_STYLE}" = "true" ]; then
		use_path_style_value="true"
	fi

	echo "Writing ${config} ..."

	if ! write_config_file; then
		fail "Error writing the object store config: ${config}"
	fi

	echo "Object store config written: ${config}"
}

main "${@}"
