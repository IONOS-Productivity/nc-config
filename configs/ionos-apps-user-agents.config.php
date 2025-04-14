<?php
$CONFIG = [
	'core.login_flow_v2.allowed_user_agents' => [
		// Use regex to match the user agent string
		// to allow the login flow for allowed apps
		'/Hidrive Next/i',
		'/com\.ionos\.hidrivenext\.desktopclient\.FileProviderUIExt/i',
	],
];
