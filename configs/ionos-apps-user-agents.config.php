<?php

/*
 * SPDX-FileCopyrightText: 2025 STRATO GmbH
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

$CONFIG = [
	'core.login_flow_v2.allowed_user_agents' => [
		// Use regex to match the user agent string
		// to allow the login flow for allowed apps
		'/Hidrive Next/i',
	],
];
