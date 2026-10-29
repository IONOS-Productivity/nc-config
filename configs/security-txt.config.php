<?php

/*
 * SPDX-FileCopyrightText: 2026 STRATO GmbH
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

// Served at /.well-known/security.txt (RFC 9116).
// "Expires" is mandatory per RFC 9116 and must be renewed before it passes.
$CONFIG = [
	'security_txt' => <<<'TXT'
		Contact: mailto:security@ionos.com
		Expires: 2028-02-11T23:30:00.000Z
		Encryption: https://keys.openpgp.org/search?q=security%40ionos.com
		Preferred-Languages: en
		Policy: https://www.ionos.com/it-security
		Hiring: https://jobs.ionos.com/
		TXT,
];
