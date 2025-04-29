<?php

$CONFIG = [
	'htaccess.RewriteBase' => '/',
	'forwarded_for_headers' => [ '0' => 'HTTP_X_FORWARDED_FOR' ],
	'auth.bruteforce.protection.enabled' => true,
	'simpleSignUpLink.shown' => false,
	'files_external_allow_create_new_local' => false,
	'allow_local_remote_servers' => true,
	'log_type' => 'errorlog',
	'loglevel' => (int)getenv('NEXTCLOUD_LOGLEVEL'),
	'log_file' => '',
	'passwordsalt' => (string)getenv('PASSWORD_SALT'),
	'secret' => (string)getenv('SECRET'),
	'session_keepalive' => true,
	'session_lifetime' => 1800,
	'skeletondirectory' => '',
	'filelocking.enabled' => true,
	'filelocking.ttl' => '43200',
];
