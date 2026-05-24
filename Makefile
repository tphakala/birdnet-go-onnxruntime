.PHONY: release local-build-linux help

ORT_VERSION ?= 1.25.1
BUILD ?= 1
TAG = v$(ORT_VERSION)-$(BUILD)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

release: ## Create and push a release tag (ORT_VERSION=1.25.1 BUILD=1)
	@if git rev-parse "$(TAG)" >/dev/null 2>&1; then \
		echo "Error: tag $(TAG) already exists"; exit 1; \
	fi
	git tag "$(TAG)"
	git push origin "$(TAG)"
	@echo "Pushed tag $(TAG) - CI will build and create the release"

local-build-linux: ## Build ORT with OpenVINO EP locally (requires OpenVINO SDK)
	./scripts/build-linux-x64.sh "$(ORT_VERSION)"
