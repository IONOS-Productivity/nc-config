#!/usr/bin/env sh

# Log fatal error message and exit with failure code
# Usage: log_fatal <message>
log_fatal() {
	echo "\033[1;31m[x] Fatal Error: ${*}\033[0m" >/dev/stderr
	exit 1
}

configure_user_oidc() {
	# unique-uid=0 is required to prevent user_oidc from creating an ID in its
	# backend that's different from the user ID in Nextcloud's own backend,
	# which leads to the user_oidc not being used during runtime.
	#
	# https://github.com/nextcloud/user_oidc/blob/v5.0.3/lib/Service/LocalIdService.php#L30
	./occ user_oidc:provider "${ENC_OIDC_PROVIDER_IDENTIFIER}" \
		--clientid="${ENC_OIDC_CLIENT_ID}" \
		--clientsecret="${ENC_OIDC_SECRET}" \
		--discoveryuri="${ENC_OIDC_DISCOVERY_URI}" \
		--extra-claims="${ENC_OIDC_EXTRA_CLAIMS}" \
		--mapping-uid="${ENC_OIDC_MAPPING_UID}" \
		--unique-uid=0 \
		--scope="${ENC_OIDC_SCOPES}"

	# Don't show a login page, send users directly to the ID provider
	./occ config:app:set --value=0 user_oidc allow_multiple_user_backends
}

main() {
	provider_id=""

	# Configure user_oidc plugin
	#
	# Expects these environment variables:
	#
	# - ENC_OIDC_CLIENT_ID (a realm in Keycloak)
	# - ENC_OIDC_SECRET
	# - ENC_OIDC_DISCOVERY_URI (format localhost:8079/realms/easystorage/.well-known/openid-configuration)
	# - ENC_OIDC_SCOPES (space separated list of scopes, usually at least "openid email profile")

	if [ ! -x "occ" ]; then
		log_fatal "occ command not found, are you in Nextcloud's root dir?"
	fi

	if ! jq --version 2>/dev/null 2>&1; then
		log_fatal "jq not found"
	fi

	if [ -z "${ENC_OIDC_PROVIDER_IDENTIFIER}" ]; then
		log_fatal "ENC_OIDC_PROVIDER_IDENTIFIER not set"
	fi

	if [ -z "${ENC_OIDC_CLIENT_ID}" ]; then
		log_fatal "ENC_OIDC_CLIENT_ID not set"
	fi

	if [ -z "${ENC_OIDC_SECRET}" ]; then
		log_fatal "ENC_OIDC_SECRET not set"
	fi

	if [ -z "${ENC_OIDC_DISCOVERY_URI}" ]; then
		log_fatal "ENC_OIDC_DISCOVERY_URI not set"
	fi

	if [ -z "${ENC_OIDC_EXTRA_CLAIMS}" ]; then
		log_fatal "ENC_OIDC_EXTRA_CLAIMS not set"
	fi

	if [ -z "${ENC_OIDC_MAPPING_UID}" ]; then
		log_fatal "ENC_OIDC_MAPPING_UID not set"
	fi

	if [ -z "${ENC_OIDC_SCOPES}" ]; then
		log_fatal "ENC_OIDC_SCOPES not set"
	fi

	if ! configure_user_oidc; then
		log_fatal "Error creating provider \"${ENC_OIDC_PROVIDER_IDENTIFIER}\" with client ID \"${ENC_OIDC_CLIENT_ID}\" (occ failed)"
	fi

	provider_id=$( ./occ user_oidc:provider "${ENC_OIDC_PROVIDER_IDENTIFIER}" --output=json | jq --arg "clientId" "${ENC_OIDC_CLIENT_ID}" 'select(.clientId == $clientId).id' 2>/dev/null )

	if [ -z "${provider_id}" ]; then
		log_fatal "Error creating provider \"${ENC_OIDC_PROVIDER_IDENTIFIER}\" with client ID \"${ENC_OIDC_CLIENT_ID}\": not found"
	fi

	echo "Provider \"${ENC_OIDC_PROVIDER_IDENTIFIER}\" with client ID \"${ENC_OIDC_CLIENT_ID}\" created. Provider ID: ${provider_id}"
}

main "${@}"
