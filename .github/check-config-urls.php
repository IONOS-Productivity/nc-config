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
 *
 * When run inside GitHub Actions (GITHUB_ACTIONS=true) it additionally emits
 * workflow commands: collapsible per-market groups, inline ::error annotations
 * pointing at the offending line, and a job-summary table. Outside CI the output
 * stays plain text.
 *
 * @see https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands
 */

const PARTIAL = __DIR__ . '/../configs/ionos-links.config.php';

// Repo-relative path used for GitHub annotations (workflow runs from repo root).
const PARTIAL_REPO_PATH = 'configs/ionos-links.config.php';

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

$inActions = getenv('GITHUB_ACTIONS') === 'true';
$partialLines = file(PARTIAL, FILE_IGNORE_NEW_LINES) ?: [];

// --- GitHub Actions workflow-command helpers ----------------------------------

/** Escape message text: only %, CR and LF need encoding. */
function gh_escape_data(string $s): string {
	return str_replace(['%', "\r", "\n"], ['%25', '%0D', '%0A'], $s);
}

/** Escape a property value: data escapes plus ':' and ','. */
function gh_escape_prop(string $s): string {
	return str_replace([':', ','], ['%3A', '%2C'], gh_escape_data($s));
}

/**
 * Emit an annotation (error|warning|notice). In CI this is a workflow command;
 * locally it degrades to a plain bullet line on stderr.
 */
function gh_issue(bool $inActions, string $level, string $message, ?string $file = null, ?int $line = null, ?string $title = null): void {
	if (!$inActions) {
		fwrite(STDERR, "  - $message\n");
		return;
	}

	$props = [];
	if ($file !== null) {
		$props[] = 'file=' . gh_escape_prop($file);
	}
	if ($line !== null) {
		$props[] = 'line=' . $line;
	}
	if ($title !== null) {
		$props[] = 'title=' . gh_escape_prop($title);
	}
	$suffix = $props === [] ? '' : ' ' . implode(',', $props);
	echo "::{$level}{$suffix}::" . gh_escape_data($message) . "\n";
}

function gh_group(bool $inActions, string $title): void {
	echo ($inActions ? "::group::$title" : "▼ $title") . "\n";
}

function gh_endgroup(bool $inActions): void {
	if ($inActions) {
		echo "::endgroup::\n";
	}
}

/** 1-based line of the first occurrence of $needle in the partial, or null. */
function find_line(array $lines, string $needle): ?int {
	foreach ($lines as $i => $text) {
		if (str_contains($text, $needle)) {
			return $i + 1;
		}
	}
	return null;
}

/** Resolve a (possibly nested) key path, or null if absent. */
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

// --- Validation ---------------------------------------------------------------

// Promote any notice/warning raised while loading the partial into a failure.
set_error_handler(static function (int $severity, string $message, string $file, int $line): bool {
	throw new ErrorException($message, 0, $severity, $file, $line);
});

/** Load the partial for a given MARKET and return the resulting $CONFIG array. */
function load_config(string $market): array {
	putenv($market === '' ? 'MARKET' : "MARKET=$market");
	$CONFIG = [];
	include PARTIAL;
	return $CONFIG;
}

$errors = [];
$perMarket = [];

foreach (MARKETS as $market) {
	$label = $market === '' ? '<unset>' : $market;
	$marketErrors = [];

	gh_group($inActions, "Validate MARKET=$label");

	try {
		$config = load_config($market);
	} catch (Throwable $e) {
		$msg = sprintf('MARKET=%s: PHP error loading partial: %s', $label, $e->getMessage());
		$marketErrors[] = $msg;
		echo "  ✗ failed to load partial\n";
		gh_issue($inActions, 'error', $msg, PARTIAL_REPO_PATH, null, 'Broken config partial');
		gh_endgroup($inActions);
		$errors = array_merge($errors, $marketErrors);
		$perMarket[$label] = $marketErrors;
		continue;
	}

	foreach (REQUIRED_URL_KEYS as $path) {
		$name = implode('.', $path);
		$value = dig($config, $path);

		if (!is_string($value) || $value === '') {
			$msg = sprintf('MARKET=%s: missing or empty URL key "%s"', $label, $name);
			$marketErrors[] = $msg;
			echo "  ✗ $name (missing)\n";
			gh_issue($inActions, 'error', $msg, PARTIAL_REPO_PATH, null, 'Missing config URL');
		} elseif (!filter_var($value, FILTER_VALIDATE_URL)) {
			$msg = sprintf('MARKET=%s: key "%s" is not a valid URL: %s', $label, $name, $value);
			$marketErrors[] = $msg;
			echo "  ✗ $name ($value)\n";
			gh_issue($inActions, 'error', $msg, PARTIAL_REPO_PATH, find_line($partialLines, "'$value'"), 'Invalid config URL');
		} elseif (parse_url($value, PHP_URL_SCHEME) !== 'https') {
			$msg = sprintf('MARKET=%s: key "%s" is not https: %s', $label, $name, $value);
			$marketErrors[] = $msg;
			echo "  ✗ $name ($value)\n";
			gh_issue($inActions, 'error', $msg, PARTIAL_REPO_PATH, find_line($partialLines, "'$value'"), 'Insecure config URL');
		} else {
			echo "  ✓ $name\n";
		}
	}

	gh_endgroup($inActions);
	$errors = array_merge($errors, $marketErrors);
	$perMarket[$label] = $marketErrors;
}

restore_error_handler();

// --- Job summary (GitHub Actions only) ----------------------------------------

$summaryPath = getenv('GITHUB_STEP_SUMMARY');
if ($summaryPath !== false && $summaryPath !== '') {
	$md = "## Config URL validation\n\n| Market | Result |\n| --- | --- |\n";
	foreach ($perMarket as $label => $marketErrors) {
		$md .= sprintf("| `%s` | %s |\n", $label, $marketErrors === [] ? '✅ ok' : '❌ ' . count($marketErrors) . ' issue(s)');
	}
	if ($errors !== []) {
		$md .= "\n### Issues\n";
		foreach ($errors as $error) {
			$md .= "- $error\n";
		}
	}
	@file_put_contents($summaryPath, $md, FILE_APPEND);
}

// --- Result -------------------------------------------------------------------

if ($errors !== []) {
	$summary = sprintf('config URL validation failed with %d issue(s)', count($errors));
	if ($inActions) {
		gh_issue($inActions, 'error', $summary, null, null, 'Config URL validation');
	} else {
		fwrite(STDERR, "❌ ERROR: $summary:\n");
		foreach ($errors as $error) {
			fwrite(STDERR, "  - $error\n");
		}
	}
	exit(1);
}

$markets = implode(', ', array_map(
	static fn (string $m): string => $m === '' ? '<unset>' : $m,
	MARKETS
));
$success = "config URL validation passed for markets: $markets";
if ($inActions) {
	gh_issue($inActions, 'notice', $success, null, null, 'Config URL validation');
} else {
	echo "✅ SUCCESS: $success\n";
}
