#!/bin/bash
# SPDX-FileCopyrightText: 2025 STRATO GmbH
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

# Validates the apps under apps-custom/ and apps-external/ and suggests the
# correct HiDrive Next Makefile category for each one.
#
# Arguments:
#   $1  CUSTOM_NPM_APPS       — apps-custom, npm only
#   $2  CUSTOM_COMPOSER_APPS  — apps-custom, composer only
#   $3  EXTERNAL_FULL_APPS    — apps-external, composer + npm
#   $4  SPECIAL_BUILD_APPS    — apps with dedicated build targets

CUSTOM_NPM_APPS="$1"
CUSTOM_COMPOSER_APPS="$2"
EXTERNAL_FULL_APPS="$3"
SPECIAL_BUILD_APPS="$4"

echo "[i] Analyzing apps under apps-custom/ and apps-external/..."

validation_failed=0
missing_app_list=""
unconfigured_app_list=""
review_app_list=""

# ── 1. Submodule status pass ──────────────────────────────────────────────────

echo ""
echo "[i] Checking git submodule status..."

if command -v git >/dev/null 2>&1; then
	submodule_status_output=$(git submodule status 2>/dev/null || echo "")
	if [ -n "$submodule_status_output" ]; then
		while IFS= read -r line; do
			[ -z "$line" ] && continue
			status_char=${line:0:1}
			submodule_path=$(echo "$line" | awk '{print $2}')
			app_name=$(basename "$submodule_path")

			case "$status_char" in
				" ") echo "  [✓] $app_name: submodule up to date" ;;
				"+") echo "  [!] $app_name: submodule has uncommitted changes" ;;
				"-")
					echo "  [✗] $app_name: submodule not initialized"
					echo "       Run: git submodule update --init $submodule_path"
					validation_failed=1
					;;
				"U")
					echo "  [✗] $app_name: submodule has merge conflicts"
					validation_failed=1
					;;
				*)  echo "  [?] $app_name: unknown submodule status ($status_char)" ;;
			esac
		done <<< "$submodule_status_output"
	else
		echo "  [i] No git submodules found (or git submodule command failed)"
	fi
else
	echo "  [!] git not available — skipping submodule status check"
fi

# ── 2. Configured apps must exist on disk ─────────────────────────────────────

echo ""
echo "[i] Checking configured apps for missing directories..."

check_path_for() {
	# echo the expected path for a given app+category combination
	local app="$1" category="$2"
	case "$category" in
		CUSTOM_NPM_APPS|CUSTOM_COMPOSER_APPS) echo "apps-custom/$app" ;;
		EXTERNAL_FULL_APPS)                   echo "apps-external/$app" ;;
		SPECIAL_BUILD_APPS)
			# specials may live in apps-custom/ OR themes/
			if   [ -d "apps-custom/$app" ];  then echo "apps-custom/$app"
			elif [ -d "themes/$app" ];        then echo "themes/$app"
			else                                   echo "apps-custom/$app"; fi
			;;
	esac
}

for category in CUSTOM_NPM_APPS CUSTOM_COMPOSER_APPS EXTERNAL_FULL_APPS SPECIAL_BUILD_APPS; do
	eval "list=\"\$$category\""
	for app in $list; do
		path=$(check_path_for "$app" "$category")
		if [ ! -d "$path" ]; then
			echo "  [✗] $app ($category): expected directory $path is missing"
			missing_app_list="$missing_app_list $app"
			validation_failed=1
		else
			echo "  [✓] $app ($category) → $path"
		fi
	done
done

# ── 3. Walk apps-custom/ and apps-external/, suggest a category ───────────────

is_in_list() {
	local needle="$1" haystack="$2"
	for x in $haystack; do
		[ "$x" = "$needle" ] && return 0
	done
	return 1
}

analyze_app() {
	local app="$1" path="$2" expected_dir="$3"

	# Skip apps that have a hardcoded special target in the Makefile
	if is_in_list "$app" "$SPECIAL_BUILD_APPS"; then
		echo "  [✓] $app → SPECIAL_BUILD_APPS (already configured)"
		return
	fi

	local has_composer=0 has_package=0 has_build=0 current=""
	[ -f "$path/composer.json" ] && has_composer=1
	[ -f "$path/package.json" ]  && has_package=1
	if [ "$has_package" -eq 1 ] && grep -q '"build"' "$path/package.json" 2>/dev/null; then
		has_build=1
	fi

	if   is_in_list "$app" "$CUSTOM_NPM_APPS";      then current="CUSTOM_NPM_APPS"
	elif is_in_list "$app" "$CUSTOM_COMPOSER_APPS"; then current="CUSTOM_COMPOSER_APPS"
	elif is_in_list "$app" "$EXTERNAL_FULL_APPS";   then current="EXTERNAL_FULL_APPS"
	fi

	# Decide the recommended category based on layout
	local recommended=""
	if [ "$expected_dir" = "apps-external" ]; then
		if [ "$has_composer" -eq 1 ] && [ "$has_package" -eq 1 ] && [ "$has_build" -eq 1 ]; then
			recommended="EXTERNAL_FULL_APPS"
		elif [ "$has_composer" -eq 1 ]; then
			recommended="SPECIAL_BUILD_APPS"   # apps-external + composer-only doesn't have a dynamic category yet
		else
			recommended="SPECIAL_BUILD_APPS"
		fi
	else
		# apps-custom/
		# Priority: if package.json has a build script, treat as npm-driven even if composer.json is present.
		# composer.json may exist for dev tooling without being part of the release build.
		if [ "$has_build" -eq 1 ]; then
			recommended="CUSTOM_NPM_APPS"
		elif [ "$has_composer" -eq 1 ] && [ "$has_package" -eq 0 ]; then
			recommended="CUSTOM_COMPOSER_APPS"
		else
			recommended="SPECIAL_BUILD_APPS"
		fi
	fi

	if [ -z "$current" ]; then
		echo "  [!] $app: NOT IN ANY LIST — suggest $recommended (add to list or removed-apps.txt)"
		unconfigured_app_list="$unconfigured_app_list $app"
	elif [ "$current" != "$recommended" ]; then
		echo "  [!] $app: in $current — Makefile analysis suggests $recommended"
		review_app_list="$review_app_list $app"
	else
		echo "  [✓] $app: $current matches Makefile analysis"
	fi
}

echo ""
echo "[i] Analyzing apps under apps-custom/..."
if [ -d "apps-custom" ]; then
	for app_path in apps-custom/*/; do
		[ -d "$app_path" ] || continue
		app=$(basename "$app_path")
		analyze_app "$app" "${app_path%/}" "apps-custom"
	done
fi

echo ""
echo "[i] Analyzing apps under apps-external/..."
if [ -d "apps-external" ]; then
	for app_path in apps-external/*/; do
		[ -d "$app_path" ] || continue
		app=$(basename "$app_path")
		analyze_app "$app" "${app_path%/}" "apps-external"
	done
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [ "$validation_failed" -eq 0 ] && [ -z "$review_app_list" ] && [ -z "$unconfigured_app_list" ]; then
	echo "[✓] All apps are properly configured"
else
	if [ -n "$missing_app_list" ];      then echo "[✗] Missing directories:$missing_app_list"; fi
	if [ -n "$unconfigured_app_list" ]; then echo "[!] Apps on disk not in any list (advisory):$unconfigured_app_list"; fi
	if [ -n "$review_app_list" ];       then echo "[!] Apps possibly miscategorized:$review_app_list"; fi
	if [ "$validation_failed" -ne 0 ];  then exit 1; fi
fi
