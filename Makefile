# SPDX-FileCopyrightText: 2024 Kai Henseler <kai.henseler@strato.de>
# SPDX-FileCopyrightText: 2025 STRATO GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Build configuration
TARGET_PACKAGE_NAME = hidrivenext-server.zip

# Common build commands
COMPOSER_INSTALL = composer install --no-dev -o --no-interaction
NPM_INSTALL      = npm ci --prefer-offline --no-audit
NPM_BUILD        = npm run build

# App category lists — drive .build_deps and generate_apps_matrix_json
# apps-custom/ — npm only (no composer)
CUSTOM_NPM_APPS = simplesettings
# apps-custom/ — composer only (no npm, even if package.json present)
CUSTOM_COMPOSER_APPS = nc_ionos_processes
# apps-external/ — full build (composer + npm)
EXTERNAL_FULL_APPS = richdocuments user_oidc viewer
# Apps with special build targets (not in the standard categories above)
# These apps have dedicated build_<app>_app targets with custom build logic
SPECIAL_BUILD_APPS = nc_theming nc-ionos-theme

# Metadata for generate_apps_matrix_json: "name|path|has_npm|has_composer"
# One entry per app in SPECIAL_BUILD_APPS — must be kept in sync.
SPECIAL_BUILD_APPS_META = \
	"nc_theming|apps-custom/nc_theming|false|true" \
	"nc-ionos-theme|themes/nc-ionos-theme|true|false"

# App folders to add to shipped.json (makes apps non-removable)
# Add additional app folders here to include them in the shipped apps list
APP_FOLDERS_TO_SHIP = \
	apps-external \
	apps-custom

# Apps to be removed from final package (read from removed-apps.txt)
REMOVE_UNWANTED_APPS = $(shell [ -f IONOS/removed-apps.txt ] && sed '/^#/d;/^$$/d;s/^/apps\//' IONOS/removed-apps.txt || echo "")

# Generate build target lists dynamically from category lists
CUSTOM_NPM_TARGETS      = $(patsubst %,build_%_app,$(CUSTOM_NPM_APPS))
CUSTOM_COMPOSER_TARGETS = $(patsubst %,build_%_app,$(CUSTOM_COMPOSER_APPS))
EXTERNAL_FULL_TARGETS   = $(patsubst %,build_%_app,$(EXTERNAL_FULL_APPS))
SPECIAL_BUILD_TARGETS   = $(patsubst %,build_%_app,$(SPECIAL_BUILD_APPS))

# Core build targets
.PHONY: help clean .precheck
# Main Nextcloud build
.PHONY: build_nextcloud build_nextcloud_only build_nextcloud_dev dev_nextcloud
# Applications — dynamically derived from category lists
.PHONY: $(CUSTOM_NPM_TARGETS) $(CUSTOM_COMPOSER_TARGETS) $(EXTERNAL_FULL_TARGETS) $(SPECIAL_BUILD_TARGETS)
# Configuration and packaging
.PHONY: add_config_partials patch_shipped_json version.json zip_dependencies
# Meta targets
.PHONY: .build_deps build_release build_locally
# Pipeline targets for CI workflow
.PHONY: build_after_external_apps package_after_build
# CI matrix generation
.PHONY: generate_apps_matrix_json

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.DEFAULT_GOAL := help

help: ## This help.
	@echo "Usage: make [target]"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Individual app build targets:"
	@for app in $(CUSTOM_NPM_APPS);      do printf "  \033[36m%-35s\033[0m %s\n" "build_$${app}_app" "apps-custom npm"; done
	@for app in $(CUSTOM_COMPOSER_APPS); do printf "  \033[36m%-35s\033[0m %s\n" "build_$${app}_app" "apps-custom composer"; done
	@for app in $(EXTERNAL_FULL_APPS);   do printf "  \033[36m%-35s\033[0m %s\n" "build_$${app}_app" "apps-external composer+npm"; done
	@for app in $(SPECIAL_BUILD_APPS);   do printf "  \033[36m%-35s\033[0m %s\n" "build_$${app}_app" "special"; done

.precheck:
	@{ \
		if [ ! -d "apps-external" ] || [ ! -d "apps-custom" ]; then \
			echo ""; \
			echo "**********************************************************************"; \
			echo "ERROR: apps-external/ or apps-custom/ not found!"; \
			echo ""; \
			echo "Run this Makefile from the Nextcloud project root:"; \
			echo "  make -f IONOS/Makefile <target>"; \
			echo "**********************************************************************"; \
			echo ""; \
			exit 1; \
		fi; \
		if ! test -f "version.php" || ! test -d "lib" || ! test -d "core"; then \
			echo ""; \
			echo "**********************************************************************"; \
			echo "ERROR: Not a valid Nextcloud project directory."; \
			echo ""; \
			echo "Run this Makefile from the Nextcloud project root:"; \
			echo "  make -f IONOS/Makefile <target>"; \
			echo "**********************************************************************"; \
			echo ""; \
			exit 1; \
		fi; \
		if ! command -v jq >/dev/null 2>&1; then \
			echo ""; \
			echo "**********************************************************************"; \
			echo "ERROR: jq is not installed!"; \
			echo ""; \
			echo "Please install jq:"; \
			echo "  Ubuntu/Debian: sudo apt-get install jq"; \
			echo "  macOS: brew install jq"; \
			echo "  Other: https://jqlang.github.io/jq/download/"; \
			echo "**********************************************************************"; \
			echo ""; \
			exit 1; \
		fi; \
	} >&2

clean: ## Clean up build artifacts
	@echo "[i] Cleaning build artifacts..."
	rm -rf node_modules
	rm -f version.json
	rm -f .buildnumber
	rm -f $(TARGET_PACKAGE_NAME)
	@echo "[✓] Clean completed"

build_nextcloud_only: ## Build HiDrive Next only (no custom npm packages rebuild)
	set -e && \
	$(COMPOSER_INSTALL) && \
	$(NPM_INSTALL) && \
	NODE_OPTIONS="--max-old-space-size=4096" $(NPM_BUILD)
	@echo "[✓] HiDrive Next core built successfully"

build_nextcloud_dev: ## Build HiDrive Next dev (no custom npm packages rebuild)
	set -e && \
	$(COMPOSER_INSTALL) && \
	$(NPM_INSTALL) && \
	NODE_OPTIONS="--max-old-space-size=4096" npm run dev
	@echo "[✓] HiDrive Next core (dev) built successfully"

build_nextcloud: build_nextcloud_only ## Build HiDrive Next
	@echo "[i] HiDrive Next built"

dev_nextcloud: build_nextcloud_dev ## Build HiDrive Next dev
	@echo "[i] HiDrive Next built"

# Common macros for standard build categories
define build_custom_npm_app
	@echo "[i] Building $(1) app..."
	@cd apps-custom/$(1) && $(NPM_INSTALL) && $(NPM_BUILD)
	@echo "[✓] $(1) app built successfully"
endef

define build_custom_composer_app
	@echo "[i] Building $(1) app..."
	@cd apps-custom/$(1) && $(COMPOSER_INSTALL)
	@echo "[✓] $(1) app built successfully"
endef

define build_external_full_app
	@echo "[i] Building $(1) app..."
	@cd apps-external/$(1) && $(COMPOSER_INSTALL) && $(NPM_INSTALL) && $(NPM_BUILD)
	@echo "[✓] $(1) app built successfully"
endef

# Dynamic rules for standard categories
$(CUSTOM_NPM_TARGETS): build_%_app:
	$(call build_custom_npm_app,$(patsubst build_%_app,%,$@))

$(CUSTOM_COMPOSER_TARGETS): build_%_app:
	$(call build_custom_composer_app,$(patsubst build_%_app,%,$@))

$(EXTERNAL_FULL_TARGETS): build_%_app:
	$(call build_external_full_app,$(patsubst build_%_app,%,$@))

# Special build targets — custom logic that doesn't fit the standard categories

build_nc_theming_app: ## Build the custom css
	@echo "[i] Building nc_theming app..."
	cd apps-custom/nc_theming && \
	$(MAKE) build_css
	@echo "[✓] nc_theming app built successfully"

build_nc-ionos-theme_app: ## Install and build ionos theme
	@echo "[i] Building nc-ionos-theme app..."
	cd themes/nc-ionos-theme/IONOS && \
	$(NPM_INSTALL) && \
	$(NPM_BUILD)
	@echo "[✓] nc-ionos-theme app built successfully"

add_config_partials: .precheck ## Copy custom config files to Nextcloud config
	@echo "[i] Copying config files..."
	cp IONOS/configs/*.config.php config/
	@echo "[✓] Config files copied successfully"

patch_shipped_json: .precheck ## Patch shipped.json
	@echo "[i] Patching shipped.json..."

	@echo "[i] Making external apps non-removable (hiding remove buttons)..."
	IONOS/scripts/patch_shipped_json_add_shipped_apps.sh $(APP_FOLDERS_TO_SHIP)

	@echo "[i] Making core apps disableable and enforcing always-enabled apps..."
	IONOS/apps-disable.sh

version.json: .precheck ## Generate version file
	@echo "[i] Generating version.json..."
	buildDate=$$(date +%s) && \
	buildRef=$$(git rev-parse --short HEAD) && \
	ncVersion=$$(php -r 'include("version.php");echo implode(".", $$OC_Version);') && \
	jq -n --arg buildDate $$buildDate --arg buildRef $$buildRef  --arg ncVersion $$ncVersion '{buildDate: $$buildDate, buildRef: $$buildRef, ncVersion: $$ncVersion}' > version.json && \
	echo "[i] version.json created" && \
	jq . version.json

zip_dependencies: patch_shipped_json version.json ## Zip relevant files
	@echo "[i] Checking if .buildnumber exists..."
	@if [ ! -f .buildnumber ]; then \
		echo ""; \
		echo "**********************************************************************"; \
		echo "ERROR: .buildnumber file not found!"; \
		echo ""; \
		echo "The .buildnumber file must exist before creating the package."; \
		echo "Inject it before packaging, e.g. echo 42 > .buildnumber"; \
		echo "**********************************************************************"; \
		echo ""; \
		exit 1; \
	fi
	@echo "[i] .buildnumber found: $$(cat .buildnumber)"
	@echo "[i] zip relevant files to $(TARGET_PACKAGE_NAME)" && \
	zip -r "$(TARGET_PACKAGE_NAME)" \
		.buildnumber \
		IONOS/ \
		3rdparty/ \
		apps/ \
		apps-custom/ \
		apps-external/ \
		config/ \
		core/ \
		dist/ \
		lib/ \
		ocs/ \
		ocs-provider/ \
		resources/ \
		themes/ \
		AUTHORS \
		composer.json \
		composer.lock \
		console.php \
		COPYING \
		cron.php \
		index.html \
		index.php \
		occ \
		public.php \
		remote.php \
		robots.txt \
		status.php \
		version.php \
		version.json  \
		.htaccess \
	-x "apps/theming/img/background/**" \
	-x "apps/*/tests/**" \
	-x "apps-*/*/.git" \
	-x "apps-*/*/composer.json" \
	-x "apps-*/*/composer.lock" \
	-x "apps-*/*/composer.phar" \
	-x "apps-*/*/.tx" \
	-x "apps-*/*/.github" \
	-x "apps-*/*/src" \
	-x "apps-*/*/node_modules**" \
	-x "apps-*/*/vendor-bin**" \
	-x "apps-*/*/tests**" \
	-x "**/cypress/**" \
	-x "*.git*" \
	-x "*.editorconfig*" \
	-x ".tx" \
	-x "composer.json" \
	-x "composer.lock" \
	-x "composer.phar" \
	-x "package.json" \
	-x "package-lock.json" \
	-x "themes/nc-ionos-theme/README.md" \
	-x "themes/nc-ionos-theme/IONOS**" \
	$(foreach app,$(REMOVE_UNWANTED_APPS),-x "$(app)/*")

.build_deps: $(CUSTOM_NPM_TARGETS) $(CUSTOM_COMPOSER_TARGETS) $(EXTERNAL_FULL_TARGETS) $(SPECIAL_BUILD_TARGETS)

build_after_external_apps: build_nextcloud add_config_partials ## Build HiDrive Next and add configs after external apps are done
	@echo "[i] HiDrive Next built and config files added"

package_after_build: zip_dependencies ## Create package after build is complete
	@echo "[i] Package created successfully"

build_release: build_nextcloud .build_deps add_config_partials zip_dependencies ## Build a release package (build apps/themes, copy configs and package)
	@echo "[i] Everything done for a release"

build_locally: dev_nextcloud .build_deps ## Build all apps/themes for local development
	@echo "[i] Everything done for local/dev"

generate_apps_matrix_json: .precheck ## Generate JSON matrix of buildable apps for the CI pipeline
	@bash -c ' \
	emit() { \
		local app="$$1" path="$$2" has_npm="$$3" has_composer="$$4"; \
		local npm_lock_path=""; \
		if [ "$$has_npm" = "true" ]; then \
			if [ -f "$$path/IONOS/package-lock.json" ]; then \
				npm_lock_path="$$path/IONOS/package-lock.json"; \
			else \
				npm_lock_path="$$path/package-lock.json"; \
			fi; \
		fi; \
		printf "{\"name\":\"%s\",\"path\":\"%s\",\"has_npm\":%s,\"has_composer\":%s,\"npm_lock_path\":\"%s\",\"makefile_target\":\"build_%s_app\",\"needs_custom_npms\":false}\n" \
			"$$app" "$$path" "$$has_npm" "$$has_composer" "$$npm_lock_path" "$$app"; \
	}; \
	for app in $(CUSTOM_NPM_APPS);      do emit "$$app" "apps-custom/$$app"   true  false; done; \
	for app in $(CUSTOM_COMPOSER_APPS); do emit "$$app" "apps-custom/$$app"   false true;  done; \
	for app in $(EXTERNAL_FULL_APPS);   do emit "$$app" "apps-external/$$app" true  true;  done; \
	for meta in $(SPECIAL_BUILD_APPS_META); do \
		app=$$(echo "$$meta" | cut -d"|" -f1); \
		path=$$(echo "$$meta" | cut -d"|" -f2); \
		has_npm=$$(echo "$$meta" | cut -d"|" -f3); \
		has_composer=$$(echo "$$meta" | cut -d"|" -f4); \
		emit "$$app" "$$path" "$$has_npm" "$$has_composer"; \
	done; \
	' | jq -s 'sort_by(.name)'
