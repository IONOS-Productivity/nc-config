<?php

/*
 * SPDX-FileCopyrightText: 2025 STRATO GmbH
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

$CONFIG = [
	'log.condition' => [
		'apps' => ['admin_audit'],
	],
	'log_type_audit' => 'errorlog',
	'syslog_tag_audit' => 'nextcloud',
	'logfile_audit' => '',
];
