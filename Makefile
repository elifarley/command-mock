# Makefile for command_mock
# Author: principal-engineering team style

# ---------- Configuration & Variables ----------
SHELL     := /bin/bash
PY        ?= python3
PIP       ?= $(PY) -m pip
HATCH     ?= hatch

# -- Tools --
BLACK     ?= black
RUFF      ?= ruff
MYPY      ?= mypy
PYTEST    ?= pytest

# -- Directories --
SRC_DIR   := src
PKG_DIR   := src/command_mock
TEST_DIR  := tests
BUILD_DIR := build
DIST_DIR  := dist
COV_HTML  := htmlcov

# -- Execution Logic (DRY) --
# If HATCH is available, we use it for running commands to ensure isolation.
# Otherwise, we fall back to the local python environment.
ifeq (, $(shell command -v $(HATCH) 2> /dev/null))
    # Hatch not found - use local python
    RUNNER := $(PY) -m
    PYTHON_CMD := $(PY)
    BUILD_CMD := $(PY) -m build
else
    # Hatch found - use hatch environment
    RUNNER := $(HATCH) run
    PYTHON_CMD := $(HATCH) run python
    BUILD_CMD := $(HATCH) build
endif

# Pytest args
PYTEST_ARGS ?= -ra
# Allow passing extra args via command line, e.g., make test ARGS="-k my_test"

# ---------- Help (Fixed) ----------
define HELP_MESSAGE
Makefile - tasks for development

Usage:
    make <target> [VAR=value]

Targets:
    help            Show this help (default)
    install         Install package + dev dependencies (editable)

    # Code Quality
    format          Auto-format code (black + ruff fix)
    check-format    Check formatting without modifying files (for CI)
    lint            Run static checks (ruff + mypy)

    # Testing
    test            Run test suite with coverage
    quick           Run tests without coverage (faster)
    test-file       Run specific test file (FILE=path)
    test-case       Run specific test case (K=pattern)
    coverage-open   Open coverage HTML report

    # Release
    version         Show current project version (calculated from git)
    release         Create and push a new release tag (V=x.y.z)

    # Build & Dist
    build           Build wheel + sdist (clean first)
    clean           Remove all build artifacts and __pycache__
    distclean       Aggressive clean (includes tool caches)

    # Automation
    ci              Run full CI pipeline (check-format, lint, test)
endef
export HELP_MESSAGE

.PHONY: help install dev format check-format lint test quick test-file test-case coverage-open build wheel sdist docs clean distclean ci release version

.DEFAULT_GOAL := help

help:
	@echo "$$HELP_MESSAGE"

# ---------- Installation ----------
install dev:
	@echo "Installing (editable mode)..."
	$(PIP) install -e ".[dev]"

# ---------- Formatting & Static Checks ----------
format: ## Format code (Write)
	@echo "Formatting code..."
	$(RUNNER) $(BLACK) $(SRC_DIR) $(TEST_DIR)
	$(RUNNER) $(RUFF) check --fix $(SRC_DIR) $(TEST_DIR)

check-format: ## Check code formatting (Read-only / CI)
	@echo "Checking formatting..."
	$(RUNNER) $(BLACK) --check $(SRC_DIR) $(TEST_DIR)
	$(RUNNER) $(RUFF) check $(SRC_DIR) $(TEST_DIR)

lint: ## Run static analysis (Ruff + Mypy)
	@echo "Running linters..."
	$(RUNNER) $(RUFF) check $(SRC_DIR) $(TEST_DIR)
	@echo "Running type checks..."
	$(RUNNER) $(MYPY) $(SRC_DIR)

# ---------- Tests ----------
test: ## Run tests with coverage
	@echo "Running tests (with coverage)..."
	$(RUNNER) $(PYTEST) --cov=$(PKG_DIR) --cov-report=html --cov-report=term $(PYTEST_ARGS) $(ARGS)

quick: ## Run tests (no coverage)
	@echo "Running quick tests..."
	$(RUNNER) $(PYTEST) $(PYTEST_ARGS) $(ARGS)

test-file: ## Run specific test file (FILE=path)
	@if [ -z "$(FILE)" ]; then echo "Error: FILE argument required. Usage: make test-file FILE=path/to/test.py"; exit 1; fi
	@echo "Running test file: $(FILE)..."
	$(RUNNER) $(PYTEST) $(PYTEST_ARGS) $(FILE) $(ARGS)

test-case: ## Run specific test case (K=pattern)
	@if [ -z "$(K)" ]; then echo "Error: K argument required. Usage: make test-case K=pattern"; exit 1; fi
	@echo "Running tests matching: $(K)..."
	$(RUNNER) $(PYTEST) $(PYTEST_ARGS) -k "$(K)" $(ARGS)

coverage-open:
	@$(PYTHON_CMD) -c "import webbrowser, os; f = os.path.join(os.getcwd(), '$(COV_HTML)', 'index.html'); print('Opening:', f); webbrowser.open('file://' + f) if os.path.exists(f) else print('Run make test first.')"

# ---------- Release ----------
version v: ## Show current project version
	@$(PYTHON_CMD) -m setuptools_scm

release: ## Create and push a new release tag
	@chmod +x scripts/release.sh
	@./scripts/release.sh $(V)

# ---------- Build & Docs ----------
build: ## Build dists
	@echo "Building distributions..."
	$(BUILD_CMD)

wheel: build
sdist: build

docs:
	@if [ -d docs ]; then \
	  echo "Building Docs..."; \
	  $(RUNNER) sphinx-build -b html docs docs/_build/html; \
	else \
	  echo "No docs directory found."; \
	fi

# ---------- Cleaning ----------
clean: ## Clean artifacts and pycache
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) $(DIST_DIR) *.egg-info .pytest_cache $(COV_HTML) docs/_build
	@echo "Cleaning python bytecode..."
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type f -name "*.pyc" -delete

distclean: clean ## Clean everything including tool caches
	@echo "Removing tool caches..."
	@rm -rf .mypy_cache .ruff_cache .venv

# ---------- CI ----------
# CI chain: check format -> static analysis -> tests
ci: check-format lint test
