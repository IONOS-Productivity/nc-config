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
	'auto_provision' => false,
	// Update *existing information* in Nextcloud backend
	// (false = fail login if existing in other backend)
	'soft_auto_provision' => false,
	'allow_multiple_user_backends' => false,
  ],
];
