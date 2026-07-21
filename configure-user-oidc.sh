#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2025 STRATO GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Log fatal error message and exit with failure code
# Usage: log_fatal <message>
log_fatal() {
	echo "\033[1;31m[x] Fatal Error: ${*}\033[0m" >/dev/stderr
	exit 1
}

# Returns the end-session endpoint URI for the given INSTANCE_TYPE and MARKET.
endsessionendpointuri() {
	case "${INSTANCE_TYPE}:${MARKET}" in
		QA:DE)       echo 'https://id.de.ac1.server.lan/logout' ;;
		QA:FR)       echo 'https://id.fr.ac1.server.lan/logout' ;;
		PRELIVE:DE)  echo 'https://id.ionos.de/logout' ;;
		PRELIVE:FR)  echo 'https://id.ionos.fr/logout' ;;
		LIVE:DE)     echo 'https://id.ionos.de/logout' ;;
		LIVE:FR)     echo 'https://id.ionos.fr/logout' ;;
		LIVE:ES)     echo 'https://id.ionos.es/logout' ;;
		LIVE:IT)     echo 'https://id.ionos.it/logout' ;;
		LIVE:GB)     echo 'https://id.ionos.co.uk/logout' ;;
	esac
}

# Returns the post-logout redirect URI for the given INSTANCE_TYPE and MARKET.
postlogouturi() {
	case "${INSTANCE_TYPE}:${MARKET}" in
		QA:DE)       echo 'https://qa.storage.ionos.de' ;;
		QA:FR)       echo 'https://qa.storage.ionos.fr' ;;
		PRELIVE:DE)  echo 'https://prelive.storage.ionos.de' ;;
		PRELIVE:FR)  echo 'https://prelive.storage.ionos.fr' ;;
		LIVE:DE)     echo 'https://storage.ionos.de' ;;
		LIVE:FR)     echo 'https://storage.ionos.fr' ;;
		LIVE:ES)     echo 'https://storage.ionos.es' ;;
		LIVE:IT)     echo 'https://storage.ionos.it' ;;
		LIVE:GB)     echo 'https://storage.ionos.co.uk' ;;
	esac
}

configure_user_oidc() {
	end_session_uri="$(endsessionendpointuri)"
	post_logout_uri="$(postlogouturi)"

	if [ -z "${end_session_uri}" ] || [ -z "${post_logout_uri}" ]; then
		if [ "${INSTANCE_TYPE}" != "DEV" ]; then
			fail "No logout URIs for INSTANCE_TYPE=${INSTANCE_TYPE} MARKET=${MARKET}"
		fi
	fi

	# unique-uid=0 is required to prevent user_oidc from creating an ID in its
	# backend that's different from the user ID in Nextcloud's own backend,
	# which leads to the user_oidc not being used during runtime.
	#
	# https://github.com/nextcloud/user_oidc/blob/v5.0.3/lib/Service/LocalIdService.php#L30
	logout_flags=""
	if [ -n "${end_session_uri}" ] && [ -n "${post_logout_uri}" ]; then
		logout_flags="--endsessionendpointuri=${end_session_uri} --postlogouturi=${post_logout_uri}"
	fi

	# shellcheck disable=SC2086
	./occ user_oidc:provider "${ENC_OIDC_PROVIDER_IDENTIFIER}" \
		--clientid="${ENC_OIDC_CLIENT_ID}" \
		--clientsecret="${ENC_OIDC_SECRET}" \
		--discoveryuri="${ENC_OIDC_DISCOVERY_URI}" \
		--extra-claims="${ENC_OIDC_EXTRA_CLAIMS}" \
		--mapping-uid="${ENC_OIDC_MAPPING_UID}" \
		--unique-uid=0 \
		--scope="${ENC_OIDC_SCOPES}" \
		--check-bearer=1 \
		--send-id-token-hint=1 \
		${logout_flags}

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

	if [ -z "${INSTANCE_TYPE}" ]; then
		fail "INSTANCE_TYPE not set"
	fi
	INSTANCE_TYPE=$(printf '%s' "${INSTANCE_TYPE}" | tr '[:lower:]' '[:upper:]')

	if [ -z "${MARKET}" ]; then
		fail "MARKET not set"
	fi
	MARKET=$(printf '%s' "${MARKET}" | tr '[:lower:]' '[:upper:]')

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
