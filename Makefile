# SPDX-FileCopyrightText: 2024 Kai Henseler <kai.henseler@strato.de>
# SPDX-License-Identifier: AGPL-3.0-or-later

TARGET_PACKAGE_NAME=easy-storage.zip

.PHONY: help .build_deps add_config_partials build_release build_locally build_dep_ionos_theme build_dep_nc_ionos_processes_app build_dep_simplesettings_app build_dep_user_oidc_app zip_dependencies

help: ## This help.
	@echo "Usage: make [target]"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.DEFAULT_GOAL := help

.remove_node_modules: ## Remove node_modules
	rm -rf node_modules

build_mdi_svg: ## Build custom mdi svg
	cd custom-npms/nc-mdi-svg && \
	FONTAWESOME_PACKAGE_TOKEN=$(FONTAWESOME_PACKAGE_TOKEN) npm ci && \
	npm run build

build_mdi_js: ## Build custom mdi js
	cd custom-npms/nc-mdi-js && \
	npm ci && \
	npm run build

build_vue_icons_package: ## Build custom vue icons package
	cd custom-npms/nc-vue-material-design-icons && \
	npm ci && \
	npm run build

build_nextcloud_vue: ## Build custom nextcloud vue
	cd custom-npms/nc-nextcloud-vue && \
	npm ci && \
	npm run build

build_nextcloud: build_mdi_svg build_mdi_js build_vue_icons_package build_nextcloud_vue ## Build Nextcloud
	composer install --no-dev -o && \
	npm ci && \
	npm run build

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

build_dep_ionos_theme: ## Install and build ionos theme
	cd themes/nc-ionos-theme/IONOS && \
	npm ci && \
	npm run build

build_dep_theming_app: ## Build the custom css
	cd apps-custom/nc_theming && \
	make build_css

add_config_partials: ## Copy custom config files to Nextcloud config
	cp IONOS/configs/*.config.php config/

zip_dependencies: ## Zip relevant files
	buildDate=$$(date +%s) && \
	buildRef=$$(git rev-parse --short HEAD) && \
	jq -n --arg buildDate $$buildDate --arg buildRef $$buildRef '{buildDate: $$buildDate, buildRef: $$buildRef}' > version.json && \
	echo "version.json created" && \
	jq . version.json && \
	echo "zip relevant files to $(TARGET_PACKAGE_NAME)" && \
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
		package.json \
		package-lock.json \
		public.php \
		remote.php \
		robots.txt \
		status.php \
		version.php \
		version.json  \
	-x "apps/theming/img/background/**" \
	-x "apps/*/tests/**" \
	-x "apps-*/*/.git" \
	-x "apps-*/*/.github" \
	-x "apps-*/*/src**" \
	-x "apps-*/*/node_modules**" \
	-x "apps-*/*/vendor-bin**" \
	-x "apps-*/*/tests**" \
	-x "**/cypress/**" \
	-x "*.git*" \
	-x "*.editorconfig*" \
	-x "themes/nc-ionos-theme/README.md" \
	-x "themes/nc-ionos-theme/IONOS**"

.build_deps: build_dep_viewer_app build_dep_simplesettings_app build_dep_nc_ionos_processes_app build_dep_user_oidc_app build_dep_ionos_theme build_dep_theming_app

build_release: build_nextcloud .build_deps add_config_partials zip_dependencies ## Build a release package (build apps/themes, copy configs and package)
	echo "Everything done for a release"

build_locally: .remove_node_modules build_nextcloud .build_deps ## Build all apps/themes for local development
	echo "Everything done for local/dev"
