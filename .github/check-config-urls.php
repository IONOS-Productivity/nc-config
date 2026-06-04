<?php

/**
 * SPDX-FileCopyrightText: 2025 STRATO GmbH
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

/**
 * Validate the market-aware IONOS links config partial.
 *
 * For every supported MARKET (plus an unset and an invalid value) this:
 *  - loads configs/ionos-links.config.php with all PHP notices/warnings promoted
 *    to failures (catches broken PHP), and
 *  - asserts every required link key is present and a well-formed https URL.
 *
 * The required-key list catches both malformed URLs (e.g. a dropped scheme) and
 * missing/renamed keys. Format/structure only — no network reachability checks,
 * to keep CI deterministic. Exits non-zero with a per-offender message on failure.
 */

const PARTIAL = __DIR__ . '/../configs/ionos-links.config.php';

// Markets to exercise: the five real ones plus the fallback paths.
const MARKETS = ['FR', 'DE', 'ES', 'UK', 'IT', '', 'INVALID_MARKET'];

// Every key here must resolve to a well-formed https URL for every market.
// Nested keys are expressed as a path (webmail lives under ionos_peer_products).
const REQUIRED_URL_KEYS = [
	['ionos_peer_products', 'ionos_webmail_target_link'],
	['ionos_help_target_link'],
	['ionos_customclient_android'],
	['ionos_customclient_ios'],
	['ionos_customclient_windows'],
	['ionos_customclient_macos'],
	['ionos_customclient_linux'],
	['ionos_customclient_nautilus'],
	['ionos_homepage'],
];

$errors = [];

// Promote any notice/warning raised while loading the partial into a failure.
set_error_handler(static function (int $severity, string $message, string $file, int $line): bool {
	throw new ErrorException($message, 0, $severity, $file, $line);
});

/**
 * Load the partial for a given MARKET and return the resulting $CONFIG array.
 */
function load_config(string $market): array {
	putenv($market === '' ? 'MARKET' : "MARKET=$market");
	$CONFIG = [];
	include PARTIAL;
	return $CONFIG;
}

/**
 * Resolve a (possibly nested) key path, or null if absent.
 */
function dig(array $config, array $path): mixed {
	$node = $config;
	foreach ($path as $segment) {
		if (!is_array($node) || !array_key_exists($segment, $node)) {
			return null;
		}
		$node = $node[$segment];
	}
	return $node;
}

foreach (MARKETS as $market) {
	$label = $market === '' ? '<unset>' : $market;

	try {
		$config = load_config($market);
	} catch (Throwable $e) {
		$errors[] = sprintf('MARKET=%s: PHP error loading partial: %s', $label, $e->getMessage());
		continue;
	}

	foreach (REQUIRED_URL_KEYS as $path) {
		$name = implode('.', $path);
		$value = dig($config, $path);

		if (!is_string($value) || $value === '') {
			$errors[] = sprintf('MARKET=%s: missing or empty URL key "%s"', $label, $name);
		} elseif (!filter_var($value, FILTER_VALIDATE_URL)) {
			$errors[] = sprintf('MARKET=%s: key "%s" is not a valid URL: %s', $label, $name, $value);
		} elseif (parse_url($value, PHP_URL_SCHEME) !== 'https') {
			$errors[] = sprintf('MARKET=%s: key "%s" is not https: %s', $label, $name, $value);
		}
	}
}

restore_error_handler();

if ($errors !== []) {
	fwrite(STDERR, "❌ ERROR: config URL validation failed:\n");
	foreach ($errors as $error) {
		fwrite(STDERR, "  - $error\n");
	}
	exit(1);
}

echo "✅ SUCCESS: config URL validation passed for markets: " . implode(', ', array_map(
	static fn (string $m): string => $m === '' ? '<unset>' : $m,
	MARKETS
)) . "\n";
