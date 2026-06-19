# Urban Assault Level Creator — developer task runner.
# Wraps the commands documented in AGENTS.md so the test suites are a single
# command instead of folklore. Override GODOT to point at a different binary:
#   make test GODOT=/path/to/godot
GODOT ?= ./Godot_v4.6.2-stable_linux.x86_64
# Isolated HOME/XDG so headless runs never touch the real user profile.
GODOT_ENV := HOME=/tmp XDG_DATA_HOME=/tmp

.DEFAULT_GOAL := help

.PHONY: help test test-py test-all run clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

test: ## Run the headless GDScript test suite
	$(GODOT_ENV) $(GODOT) --headless --path . --script res://tests/test_runner.gd

test-py: ## Run the Python (sky conversion) test suite
	PYTHONPATH=. pytest tests/ -q

test-all: test test-py ## Run both test suites

run: ## Open the project in the pinned Godot editor
	$(GODOT) --path . --editor

clean: ## Remove Python bytecode caches
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
