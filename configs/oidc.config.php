<?php
$CONFIG = [
	'user_oidc' => [
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
	],
];
