# SPDX-FileCopyrightText: 2024 Kai Henseler <kai.henseler@strato.de>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Build configuration
TARGET_PACKAGE_NAME = hidrivenext-server.zip

# Required environment variables:
# - FONTAWESOME_PACKAGE_TOKEN: Token for FontAwesome package access

# Environment variable validation
check-env:
	@if [ -z "$(FONTAWESOME_PACKAGE_TOKEN)" ]; then \
		echo "Error: FONTAWESOME_PACKAGE_TOKEN environment variable is not set"; \
		echo "Please set it before building custom npm packages"; \
		exit 1; \
	fi

# Core build targets
.PHONY: help clean .remove_node_modules check-env
# Custom NPM packages
.PHONY: build_custom_npms build_mdi_svg build_mdi_js build_vue_icons_package build_nextcloud_vue
# Main Nextcloud build
.PHONY: build_nextcloud build_nextcloud_only
# Applications
.PHONY: build_dep_simplesettings_app build_dep_nc_ionos_processes_app build_dep_user_oidc_app build_dep_viewer_app build_richdocuments_app build_dep_theming_app
# Themes
.PHONY: build_dep_ionos_theme
# Configuration and packaging
.PHONY: add_config_partials patch_shipped_json version.json zip_dependencies
# Meta targets
.PHONY: .build_deps build_release build_locally

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

.remove_node_modules: ## Remove node_modules
	@echo "[i] Removing node_modules directories..."
	rm -rf node_modules

build_mdi_svg: check-env ## Build custom mdi svg
	@echo "[i] Building custom MDI SVG package..."
	cd custom-npms/nc-mdi-svg && \
	FONTAWESOME_PACKAGE_TOKEN=$(FONTAWESOME_PACKAGE_TOKEN) npm ci && \
	npm run build

build_mdi_js: ## Build custom mdi js
	@echo "[i] Building custom MDI JS package..."
	cd custom-npms/nc-mdi-js && \
	npm ci && \
	npm run build

build_vue_icons_package: ## Build custom vue icons package
	@echo "[i] Building custom Vue icons package..."
	cd custom-npms/nc-vue-material-design-icons && \
	npm ci && \
	npm run build

build_nextcloud_vue: ## Build custom nextcloud vue
	@echo "[i] Building custom Nextcloud Vue package..."
	cd custom-npms/nc-nextcloud-vue && \
	npm ci && \
	npm run build

build_custom_npms: .remove_node_modules build_mdi_svg build_mdi_js build_vue_icons_package build_nextcloud_vue ## Build all custom npm packages
	@echo "[i] Custom npm packages built"

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

build_nextcloud: build_custom_npms build_nextcloud_only ## Build HiDrive Next (rebuild custom npm packages)
	@echo "[i] HiDrive Next built"

dev_nextcloud: build_custom_npms build_nextcloud_dev ## Build HiDrive Next (rebuild custom npm packages)
	@echo "[i] HiDrive Next built"

build_dep_simplesettings_app: ## Install and build simplesettings app
	cd apps-custom/simplesettings && \
	npm ci && \
	npm run build

build_dep_nc_ionos_processes_app: ## Install nc_ionos_processes app
	cd apps-custom/nc_ionos_processes && \
	composer install --no-dev -o

build_dep_user_oidc_app: ## Install and build user_oidc app
	cd apps-external/user_oidc && \
	composer install --no-dev -o && \
	npm ci && \
	npm run build

build_dep_viewer_app: ## Install and build viewer app
	cd apps-external/viewer && \
	composer install --no-dev -o && \
	npm ci && \
	npm run build

build_richdocuments_app: ## Install and build richdocuments viewer app
	cd apps-external/richdocuments && \
	composer install --no-dev -o && \
	npm ci && \
	npm run build

build_dep_ionos_theme: ## Install and build ionos theme
	cd themes/nc-ionos-theme/IONOS && \
	npm ci && \
	npm run build

build_dep_theming_app: ## Build the custom css
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
	@echo "[i] zip relevant files to $(TARGET_PACKAGE_NAME)" && \
	zip -r "$(TARGET_PACKAGE_NAME)" \
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

.build_deps: build_dep_viewer_app build_richdocuments_app build_dep_simplesettings_app build_dep_nc_ionos_processes_app build_dep_user_oidc_app build_dep_ionos_theme build_dep_theming_app

build_release: build_nextcloud .build_deps add_config_partials zip_dependencies ## Build a release package (build apps/themes, copy configs and package)
	@echo "[i] Everything done for a release"

build_locally: dev_nextcloud .build_deps ## Build all apps/themes for local development
	@echo "[i] Everything done for local/dev"
