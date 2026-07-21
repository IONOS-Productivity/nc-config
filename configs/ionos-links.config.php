<?php

/*
 * SPDX-FileCopyrightText: 2025 STRATO GmbH
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

$CONFIG = (static function (): array {
	$market = strtoupper((string)getenv('MARKET'));

	$marketLinks = [
		'FR' => [
			'ionos_peer_products' => [
				'ionos_webmail_target_link' => 'https://email.ionos.fr/',
			],
			'ionos_help_target_link' => 'https://wl.hidrive.com/easy/0027',
			'ionos_security_target_link' => 'https://my.ionos.fr/productuser/security',
			'ionos_customclient_android' => 'https://wl.hidrive.com/easy/0022',
			'ionos_customclient_ios' => 'https://wl.hidrive.com/easy/0021',
			'ionos_homepage' => 'https://ionos.fr/',
		],
		'DE' => [
			'ionos_peer_products' => [
				'ionos_webmail_target_link' => 'https://email.ionos.de/',
			],
			'ionos_help_target_link' => 'https://wl.hidrive.com/easy/0047',
			'ionos_security_target_link' => 'https://mein.ionos.de/productuser/security',
			'ionos_customclient_android' => 'https://wl.hidrive.com/easy/0002',
			'ionos_customclient_ios' => 'https://wl.hidrive.com/easy/0001',
			'ionos_homepage' => 'https://ionos.de/',
		],
		'ES' => [
			'ionos_peer_products' => [
				'ionos_webmail_target_link' => 'https://email.ionos.es/',
			],
			'ionos_help_target_link' => 'https://wl.hidrive.com/easy/0017',
			'ionos_security_target_link' => 'https://my.ionos.es/productuser/security',
			'ionos_customclient_android' => 'https://wl.hidrive.com/easy/0032',
			'ionos_customclient_ios' => 'https://wl.hidrive.com/easy/0031',
			'ionos_homepage' => 'https://ionos.es/',
		],
		'GB' => [
			'ionos_peer_products' => [
				'ionos_webmail_target_link' => 'https://email.ionos.co.uk/',
			],
			'ionos_help_target_link' => 'https://wl.hidrive.com/easy/0007',
			'ionos_security_target_link' => 'https://my.ionos.co.uk/productuser/security',
			'ionos_customclient_android' => 'https://wl.hidrive.com/easy/0012',
			'ionos_customclient_ios' => 'https://wl.hidrive.com/easy/0011',
			'ionos_homepage' => 'https://ionos.co.uk/',
		],
		'IT' => [
			'ionos_peer_products' => [
				'ionos_webmail_target_link' => 'https://email.ionos.it/',
			],
			'ionos_help_target_link' => 'https://wl.hidrive.com/easy/0037',
			'ionos_security_target_link' => 'https://my.ionos.it/productuser/security',
			'ionos_customclient_android' => 'https://wl.hidrive.com/easy/0033',
			'ionos_customclient_ios' => 'https://wl.hidrive.com/easy/00311',
			'ionos_homepage' => 'https://ionos.it/',
		],
	];

	if (!isset($marketLinks[$market])) {
		if ($market !== '') {
			error_log(sprintf('MARKET invalid (%s), defaulting to DE links', $market));
		}
		$market = 'DE';
	}

	return array_merge([
		'ionos_customclient_windows' => 'https://wl.hidrive.com/easy/0003',
		'ionos_customclient_macos' => 'https://wl.hidrive.com/easy/1003',
		'ionos_customclient_ios_appid' => '6738140194',
		'ionos_customclient_linux' => 'https://wl.hidrive.com/easy/2003',
		'ionos_customclient_nautilus' => 'https://wl.hidrive.com/easy/2004',
		'simpleSignUpLink.shown' => false,
	], $marketLinks[$market]);
})();
