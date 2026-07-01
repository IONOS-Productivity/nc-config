<?php

$CONFIG = (static function (): array {
	$market = strtoupper((string)getenv('MARKET'));
	$instanceType = strtoupper((string)getenv('INSTANCE_TYPE'));

	// endsessionendpointuri and postlogouturi are market- and env-specific.
	$logoutUris = [
		'QA' => [
			'DE' => [
				'endsessionendpointuri' => 'https://id.de.ac1.server.lan/logout',
				'postlogouturi' => 'https://qa.storage.ionos.de',
			],
			'FR' => [
				'endsessionendpointuri' => 'https://id.fr.ac1.server.lan/logout',
				'postlogouturi' => 'https://qa.storage.ionos.fr',
			],
		],
		'PRELIVE' => [
			'DE' => [
				'endsessionendpointuri' => 'https://id.ionos.de/logout',
				'postlogouturi' => 'https://prelive.storage.ionos.de',
			],
			'FR' => [
				'endsessionendpointuri' => 'https://id.ionos.fr/logout',
				'postlogouturi' => 'https://prelive.storage.ionos.fr',
			],
		],
		'LIVE' => [
			'DE' => [
				'endsessionendpointuri' => 'https://id.ionos.de/logout',
				'postlogouturi' => 'https://storage.ionos.de',
			],
			'FR' => [
				'endsessionendpointuri' => 'https://id.ionos.fr/logout',
				'postlogouturi' => 'https://storage.ionos.fr',
			],
			'ES' => [
				'endsessionendpointuri' => 'https://id.ionos.es/logout',
				'postlogouturi' => 'https://storage.ionos.es',
			],
			'IT' => [
				'endsessionendpointuri' => 'https://id.ionos.it/logout',
				'postlogouturi' => 'https://storage.ionos.it',
			],
			'UK' => [
				'endsessionendpointuri' => 'https://id.ionos.co.uk/logout',
				'postlogouturi' => 'https://storage.ionos.co.uk',
			],
		],
	];

	$uris = $logoutUris[$instanceType][$market] ?? [];

	if ($uris === []) {
		error_log(sprintf(
			'oidc.config.php: no logout URIs for INSTANCE_TYPE=%s MARKET=%s',
			$instanceType,
			$market,
		));
	}

	return [
		'user_oidc' => array_merge([
			'enable_default_claims' => false,
			// When default claims are disabled, each claim will be asked for
			// only if there is an attribute explicitely mapped in the OpenId
			// client settings
			'use_pkce' => true,
			// true and true are the defaults
			// > If the user already exists in another backend, we don't create a
			// > new one in the user_oidc backend. We update the information
			// > (mapped attributes) of the existing user. If the user does not
			// > exist in another backend, we create it in the user_oidc backend
			// https://github.com/nextcloud/user_oidc#soft-auto-provisioning
			'auto_provision' => true,
			// Update *existing information* in Nextcloud backend
			// (false = fail login if existing in other backend)
			'soft_auto_provision' => true,
			// > Soft auto provisioning but prevent user_oidc to create users,
			// > meaning you want user_oidc to accept connection only for users that already exist in Nextcloud
			// > and are managed by other user backend BUT you still want user_oidc to set the user information
			// > according to the OIDC mapped attributes.
			//
			// https://github.com/nextcloud/user_oidc?tab=readme-ov-file#soft-auto-provisioning-without-user-creation
			'disable_account_creation' => true,
			// IONOS access tokens carry aud=ionos.com, not per-client values;
			// audience check must be off (permanent)
			'selfencoded_bearer_validation_audience_check' => false,
			// Enable UserInfo fallback for mappingUid claim resolution
			// (IONOS access tokens lack the claim; permanent per AD-7, CISOLOGIN-902)
			'userinfo_bearer_validation' => true,
		], $uris),
	];
})();
