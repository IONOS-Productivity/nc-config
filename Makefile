# SPDX-FileCopyrightText: 2024 Kai Henseler <kai.henseler@strato.de>
# SPDX-FileCopyrightText: 2025 STRATO GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Build configuration
TARGET_PACKAGE_NAME = hidrivenext-server.zip

# App category lists — drive .build_deps and generate_apps_matrix_json
# apps-custom/ — npm only (no composer)
CUSTOM_NPM_APPS = simplesettings
# apps-custom/ — composer only (no npm, even if package.json present)
CUSTOM_COMPOSER_APPS = nc_ionos_processes nc_theming
# apps-external/ — full build (composer + npm)
EXTERNAL_FULL_APPS = richdocuments user_oidc viewer
# themes/ — npm only; lock file lives under ${path}/IONOS/
THEME_APPS = nc-ionos-theme

# Core build targets
.PHONY: help clean
# Main Nextcloud build
.PHONY: build_nextcloud build_nextcloud_only
# Applications and themes — dynamically derived from category lists
.PHONY: $(patsubst %,build_%_app,$(CUSTOM_NPM_APPS) $(CUSTOM_COMPOSER_APPS) $(EXTERNAL_FULL_APPS) $(THEME_APPS))
# Configuration and packaging
.PHONY: add_config_partials patch_shipped_json version.json zip_dependencies
# Meta targets
.PHONY: .build_deps build_release build_locally
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

clean: ## Clean up build artifacts
	@echo "[i] Cleaning build artifacts..."
	rm -rf node_modules
	rm -f version.json
	rm -f $(TARGET_PACKAGE_NAME)

build_nextcloud_only:  ## Build HiDrive Next only (no custom npm packages rebuild)
	set -e && \
	composer install --no-dev -o && \
	npm ci && \
	NODE_OPTIONS="--max-old-space-size=4096" npm run build

build_nextcloud_dev:  ## Build HiDrive Next only (no custom npm packages rebuild)
	set -e && \
	composer install --no-dev -o && \
	npm ci && \
	NODE_OPTIONS="--max-old-space-size=4096" npm run dev

build_nextcloud: build_nextcloud_only ## Build HiDrive Next
	@echo "[i] HiDrive Next built"

dev_nextcloud: build_nextcloud_dev ## Build HiDrive Next (dev)
	@echo "[i] HiDrive Next built"

build_simplesettings_app: ## Install and build simplesettings app
	cd apps-custom/simplesettings && \
	npm ci && \
	npm run build

build_nc_ionos_processes_app: ## Install nc_ionos_processes app
	cd apps-custom/nc_ionos_processes && \
	composer install --no-dev -o

build_user_oidc_app: ## Install and build user_oidc app
	cd apps-external/user_oidc && \
	composer install --no-dev -o && \
	npm ci && \
	npm run build

build_viewer_app: ## Install and build viewer app
	cd apps-external/viewer && \
	composer install --no-dev -o && \
	npm ci && \
	npm run build

build_richdocuments_app: ## Install and build richdocuments viewer app
	cd apps-external/richdocuments && \
	composer install --no-dev -o && \
	npm ci && \
	npm run build

build_nc-ionos-theme_app: ## Install and build ionos theme
	cd themes/nc-ionos-theme/IONOS && \
	npm ci && \
	npm run build

build_nc_theming_app: ## Build the custom css
	cd apps-custom/nc_theming && \
	make build_css

add_config_partials: ## Copy custom config files to Nextcloud config
	@echo "[i] Copying config files..."
	cp IONOS/configs/*.config.php config/

patch_shipped_json: ## Patch shipped.json to make core apps disableable
	@echo "[i] Patching shipped.json..."
	IONOS/apps-disable.sh

version.json: ## Generate version file
	@echo "[i] Generating version.json..."
	buildDate=$$(date +%s) && \
	buildRef=$$(git rev-parse --short HEAD) && \
	ncVersion=$$(php -r 'include("version.php");echo implode(".", $$OC_Version);') && \
	jq -n --arg buildDate $$buildDate --arg buildRef $$buildRef  --arg ncVersion $$ncVersion '{buildDate: $$buildDate, buildRef: $$buildRef, ncVersion: $$ncVersion}' > version.json && \
	echo "[i] version.json created" && \
	jq . version.json

zip_dependencies: patch_shipped_json version.json ## Zip relevant files
	@if [ ! -f .buildnumber ]; then \
		echo "Error: .buildnumber file is missing. Inject it before packaging (e.g. echo 42 > .buildnumber)"; \
		exit 1; \
	fi
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
	-x "themes/nc-ionos-theme/IONOS**"

.build_deps: $(patsubst %,build_%_app,$(CUSTOM_NPM_APPS) $(CUSTOM_COMPOSER_APPS) $(EXTERNAL_FULL_APPS) $(THEME_APPS))

build_release: build_nextcloud .build_deps add_config_partials zip_dependencies ## Build a release package (build apps/themes, copy configs and package)
	@echo "[i] Everything done for a release"

build_locally: dev_nextcloud .build_deps ## Build all apps/themes for local development
	@echo "[i] Everything done for local/dev"

generate_apps_matrix_json: ## Generate JSON matrix of buildable apps for the CI pipeline
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
	for app in $(THEME_APPS);           do emit "$$app" "themes/$$app"        true  false; done \
	' | jq -s 'sort_by(.name)'
