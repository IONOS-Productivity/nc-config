#!/bin/bash
# SPDX-FileCopyrightText: 2025 STRATO GmbH
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

# Validates that apps are only in one list and not duplicated by hardcoded targets.
# Arguments:
#   $1  CUSTOM_NPM_APPS      — space-separated list
#   $2  CUSTOM_COMPOSER_APPS — space-separated list
#   $3  EXTERNAL_FULL_APPS   — space-separated list
#   $4  SPECIAL_BUILD_APPS   — space-separated list
#   $5  MAKEFILE_PATH        — path to the Makefile to inspect for hardcoded targets

CUSTOM_NPM_APPS="$1"
CUSTOM_COMPOSER_APPS="$2"
EXTERNAL_FULL_APPS="$3"
SPECIAL_BUILD_APPS="$4"
MAKEFILE_PATH="$5"

echo "[i] Validating app list uniqueness..."

validation_failed=0

all_apps="$CUSTOM_NPM_APPS $CUSTOM_COMPOSER_APPS $EXTERNAL_FULL_APPS $SPECIAL_BUILD_APPS"

# ── 1. Cross-list duplicate check ─────────────────────────────────────────────

echo "[i] Checking for duplicate apps across lists..."
echo ""

for app in $all_apps; do
	count=0
	locations=""

	for a in $CUSTOM_NPM_APPS;      do [ "$app" = "$a" ] && { count=$((count + 1)); locations="$locations CUSTOM_NPM_APPS";      break; }; done
	for a in $CUSTOM_COMPOSER_APPS; do [ "$app" = "$a" ] && { count=$((count + 1)); locations="$locations CUSTOM_COMPOSER_APPS"; break; }; done
	for a in $EXTERNAL_FULL_APPS;   do [ "$app" = "$a" ] && { count=$((count + 1)); locations="$locations EXTERNAL_FULL_APPS";   break; }; done
	for a in $SPECIAL_BUILD_APPS;   do [ "$app" = "$a" ] && { count=$((count + 1)); locations="$locations SPECIAL_BUILD_APPS";   break; }; done

	if [ "$count" -gt 1 ]; then
		echo "ERROR: App \"$app\" appears in multiple lists:$locations"
		validation_failed=1
	fi
done

# ── 2. Hardcoded-target conflict check ────────────────────────────────────────
# Apps in the three dynamic categories must NOT have a hardcoded build_<app>_app
# target — such a target would shadow the dynamic pattern rule.

echo "[i] Checking for hardcoded build targets that conflict with dynamic lists..."
echo ""

dynamic_apps="$CUSTOM_NPM_APPS $CUSTOM_COMPOSER_APPS $EXTERNAL_FULL_APPS"

# Find all hardcoded build_*_app: targets in the Makefile (one or more, in case
# MAKEFILE_LIST contains multiple files separated by spaces).
hardcoded_targets=$(grep -hE "^build_[a-zA-Z0-9_-]+_app:" $MAKEFILE_PATH 2>/dev/null | sed 's/^build_//;s/_app:.*//' || true)

for target in $hardcoded_targets; do
	for app in $dynamic_apps; do
		if [ "$target" = "$app" ]; then
			echo "ERROR: App \"$app\" has a hardcoded build_${app}_app target but is also in a dynamic list"
			echo "       Either remove the hardcoded target and rely on dynamic rules, or move the app to SPECIAL_BUILD_APPS"
			validation_failed=1
			break
		fi
	done
done

# ── 3. SPECIAL_BUILD_APPS must have hardcoded targets ─────────────────────────

echo "[i] Checking that SPECIAL_BUILD_APPS have corresponding hardcoded targets..."
echo ""

for app in $SPECIAL_BUILD_APPS; do
	found=0
	for target in $hardcoded_targets; do
		if [ "$app" = "$target" ]; then
			found=1
			break
		fi
	done

	if [ "$found" -eq 0 ]; then
		echo "ERROR: App \"$app\" is in SPECIAL_BUILD_APPS but has no hardcoded build_${app}_app target"
		echo "       Either add a hardcoded target or move the app to an appropriate dynamic list"
		validation_failed=1
	fi
done

if [ "$validation_failed" -eq 0 ]; then
	echo "[✓] All apps are uniquely categorized with no conflicts"
else
	echo ""
	echo "[✗] Validation failed — please fix the issues above"
	exit 1
fi
